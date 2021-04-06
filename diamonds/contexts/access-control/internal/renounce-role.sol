// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../data.sol";
import "./has-role.sol";

abstract contract int_renounceRole_AccessControl_v1 is
    dat_AccessControl_v1,
    int_hasRole_AccessControl_v1
{
    function _renounceRole(bytes32 role, address account) internal {
        require(_hasRole(role, msg.sender), "CAN'T RENOUNCE");
        accessControlRolesStore().roles[role].members[account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }
}
