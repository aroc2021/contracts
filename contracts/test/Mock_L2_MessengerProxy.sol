// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../bridges/L2_PolygonMessengerProxy.sol";

contract Mock_L2_MessengerProxy is L2_PolygonMessengerProxy {
    constructor (address _l2Bridge) public L2_PolygonMessengerProxy(_l2Bridge) {}
}
