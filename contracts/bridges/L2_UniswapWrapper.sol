// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./L2_Bridge.sol";
import "../interfaces/IWETH.sol";

contract L2_UniswapWrapper {
    using SafeERC20 for IERC20;

    L2_Bridge public bridge;
    IERC20 public l2CanonicalToken;
    bool public l2CanonicalTokenIsEth;
    IERC20 public hToken;
    IUniswapV2Router02 public exchangeAddress;

    /// @notice When l2CanonicalTokenIsEth is true, l2CanonicalToken should be set to the WETH address
    constructor(
        L2_Bridge _bridge,
        IERC20 _l2CanonicalToken,
        bool _l2CanonicalTokenIsEth,
        IERC20 _hToken,
        IUniswapV2Router02 _exchangeAddress
    )
        public
    {
        bridge = _bridge;
        l2CanonicalToken = _l2CanonicalToken;
        l2CanonicalTokenIsEth = _l2CanonicalTokenIsEth;
        hToken = _hToken;
        exchangeAddress = _exchangeAddress;
    }

    /// @notice amount is the amount the user wants to send plus the Bonder fee
    function swapAndSend(
        uint256 chainId,
        address recipient,
        uint256 amount,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline,
        uint256 destinationAmountOutMin,
        uint256 destinationDeadline
    )
        external
        payable
    {
        require(amount >= bonderFee, "L2_BRG: Bonder fee cannot exceed amount");

        if (l2CanonicalTokenIsEth) {
            require(msg.value == amount, "L2_BRG: Value does not match amount");
            IWETH(address(l2CanonicalToken)).deposit{value: amount}();
        } else {
            l2CanonicalToken.safeTransferFrom(msg.sender, address(this), amount);
        }

        address[] memory exchangePath = _getCHPath();
        uint256[] memory swapAmounts = IUniswapV2Router02(exchangeAddress).getAmountsOut(amount, exchangePath);
        uint256 swapAmount = swapAmounts[1];

        l2CanonicalToken.approve(address(exchangeAddress), amount);
        IUniswapV2Router02(exchangeAddress).swapExactTokensForTokens(
            amount,
            amountOutMin,
            exchangePath,
            msg.sender,
            deadline
        );

        bridge.send(chainId, recipient, swapAmount, bonderFee, destinationAmountOutMin, destinationDeadline);
    }

    function attemptSwap(address recipient, uint256 amount, uint256 amountOutMin, uint256 deadline) external {
        hToken.safeTransferFrom(msg.sender, address(this), amount);

        bool success = true;
        if (l2CanonicalTokenIsEth) {
            try IUniswapV2Router02(exchangeAddress).swapExactTokensForETH(
                amount,
                amountOutMin,
                _getHCPath(),
                recipient,
                deadline
            ) returns (uint[] memory) {} catch {
                success = false;
            }
        } else {
            try IUniswapV2Router02(exchangeAddress).swapExactTokensForTokens(
                amount,
                amountOutMin,
                _getHCPath(),
                recipient,
                deadline
            ) returns (uint[] memory) {} catch {
                success = false;
            }
        }

        if (!success) {
            // Transfer hToken to recipient if swap fails
            hToken.safeTransfer(recipient, amount);
        }
    }

    function _getHCPath() private view returns (address[] memory) {
        address[] memory exchangePath = new address[](2);
        exchangePath[0] = address(hToken);
        exchangePath[1] = address(l2CanonicalToken);
        return exchangePath;
    }

    function _getCHPath() private view returns (address[] memory) {
        address[] memory exchangePath = new address[](2);
        exchangePath[0] = address(l2CanonicalToken);
        exchangePath[1] = address(hToken);
        return exchangePath;
    }
}
