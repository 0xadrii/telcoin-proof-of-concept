// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SablierV2Comptroller} from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import {SablierV2NFTDescriptor} from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";
import {SablierV2LockupLinear} from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import {ISablierV2Comptroller} from "@sablier/v2-core/src/interfaces/ISablierV2Comptroller.sol";
import {ISablierV2NFTDescriptor} from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

import {CouncilMember, IPRBProxy} from "../src/core/CouncilMember.sol";
import {TestTelcoin} from "./mock/TestTelcoin.sol";
import {MockProxyTarget} from "./mock/MockProxyTarget.sol";
import {PRBProxy} from "./mock/MockPRBProxy.sol";
import {PRBProxyRegistry} from "./mock/MockPRBProxyRegistry.sol";

import {UD60x18} from "@prb/math/src/UD60x18.sol";
import {LockupLinear, Broker, IERC20} from "@sablier/v2-core/src/types/DataTypes.sol";
import {IERC20 as IERC20OZ} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PocTest is Test {

    ////////////////////////////////////////////////////////////////
    //                        CONSTANTS                           //
    ////////////////////////////////////////////////////////////////

   bytes32 public constant GOVERNANCE_COUNCIL_ROLE =
        keccak256("GOVERNANCE_COUNCIL_ROLE");
    bytes32 public constant SUPPORT_ROLE = keccak256("SUPPORT_ROLE");


    ////////////////////////////////////////////////////////////////
    //                         STORAGE                            //
    ////////////////////////////////////////////////////////////////

    /// @notice Poc Users
    address public sablierAdmin;
    address public user;

    /// @notice Sablier contracts
    SablierV2Comptroller public comptroller;
    SablierV2NFTDescriptor public nftDescriptor;
    SablierV2LockupLinear public lockupLinear;

    /// @notice Telcoin contracts
    PRBProxyRegistry public proxyRegistry;
    PRBProxy public stream;
    MockProxyTarget public target;
    CouncilMember public councilMember;
    TestTelcoin public telcoin;

    function setUp() public {
        // Setup users
        _setupUsers();

        // Deploy token
        telcoin = new TestTelcoin(address(this));

        // Deploy Sablier 
        _deploySablier();

        // Deploy council member
        councilMember = new CouncilMember();

        // Setup stream
        _setupStream();

        // Setup the council member
        _setupCouncilMember();
    }

    function testPoc() public {
      // Step 1: Mint council NFT to user
      councilMember.mint(user);
      assertEq(councilMember.balanceOf(user), 1);

      // Step 2: Forward time 1 days
      vm.warp(block.timestamp + 1 days);
      
      // Step 3: All functions calling _retrieve() (mint(), burn(), removeFromOffice()) more than once will fail
      vm.expectRevert(abi.encodeWithSignature("PRBProxy_ExecutionReverted()")); 
      councilMember.mint(user);

    }

    function _setupUsers() internal {
        sablierAdmin = makeAddr("sablierAdmin");
        user = makeAddr("user");
    }

    function _deploySablier() internal {
        // Deploy protocol
        comptroller = new SablierV2Comptroller(sablierAdmin);
        nftDescriptor = new SablierV2NFTDescriptor();
        lockupLinear = new SablierV2LockupLinear(
            sablierAdmin,
            ISablierV2Comptroller(address(comptroller)),
            ISablierV2NFTDescriptor(address(nftDescriptor))
        );
    }

    function _setupStream() internal {

        // Deploy proxies
        proxyRegistry = new PRBProxyRegistry();
        stream = PRBProxy(payable(address(proxyRegistry.deploy())));
        target = new MockProxyTarget();

        // Setup stream
        LockupLinear.Durations memory durations = LockupLinear.Durations({
            cliff: 0,
            total: 1 weeks
        });

        UD60x18 fee = UD60x18.wrap(0);

        Broker memory broker = Broker({account: address(0), fee: fee});
        LockupLinear.CreateWithDurations memory params = LockupLinear
            .CreateWithDurations({
                sender: address(this),
                recipient: address(stream),
                totalAmount: 100e18,
                asset: IERC20(address(telcoin)),
                cancelable: false,
                transferable: false,
                durations: durations,
                broker: broker
            });

        bytes memory data = abi.encodeWithSelector(target.createWithDurations.selector, address(lockupLinear), params, "");

        // Create the stream through the PRBProxy
        telcoin.approve(address(stream), type(uint256).max);
        bytes memory response = stream.execute(address(target), data);
        assertEq(lockupLinear.ownerOf(1), address(stream));
    }

    function _setupCouncilMember() internal {
      // Initialize
      councilMember.initialize(
            IERC20OZ(address(telcoin)),
            "Test Council",
            "TC",
            IPRBProxy(address(stream)), // stream_
            address(target), // target_
            1, // id_
            address(lockupLinear)
        );

        // Grant roles
        councilMember.grantRole(GOVERNANCE_COUNCIL_ROLE, address(this));
        councilMember.grantRole(SUPPORT_ROLE, address(this));
    }
  
}
