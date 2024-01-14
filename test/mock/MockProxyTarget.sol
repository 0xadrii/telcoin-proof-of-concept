// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {ISablierV2Lockup} from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {LockupLinear, IERC20} from "@sablier/v2-core/src/types/DataTypes.sol";
import {IPRBProxy} from "./interfaces/IPRBProxy.sol";

import "./MockOnlyDelegateCall.sol";

/// @title Mock SablierV2ProxyTarget
contract MockProxyTarget is MockOnlyDelegateCall {
    function createWithDurations(
        ISablierV2LockupLinear lockupLinear,
        LockupLinear.CreateWithDurations calldata createParams,
        bytes calldata transferData
    ) public onlyDelegateCall returns (uint256 streamId) {
        _handleTransfer(
            address(lockupLinear),
            createParams.asset,
            createParams.totalAmount,
            transferData
        );
        streamId = lockupLinear.createWithDurations(createParams);
    }

    function _handleTransfer(
        address sablierContract,
        IERC20 asset,
        uint160 amount,
        bytes calldata /* transferData */
    ) internal {
        // Retrieve the proxy owner.
        address owner = _getOwner();

        // Transfer funds from the proxy owner to the proxy.
        asset.transferFrom(owner, address(this), amount);

        // Approve the Sablier contract to spend funds.
        _approve(sablierContract, asset, amount);
    }

    function _getOwner() internal view returns (address) {
        return IPRBProxy(address(this)).owner();
    }

    function _approve(
        address sablierContract,
        IERC20 asset,
        uint256 amount
    ) internal {
        asset.approve(sablierContract, amount);
    }
 
    function withdrawMax(ISablierV2Lockup lockup, uint256 streamId, address to) external onlyDelegateCall {
        lockup.withdrawMax(streamId, to);
    }
}
 