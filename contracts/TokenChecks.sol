// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./lib/IERC20.sol";
import "./lib/UniswapV2Library08.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
// Adapted from https://github.com/0xV19/TokenProvidence/blob/master/contracts/TokenProvidence.sol
// Buy and sell token. Keep track of ETH before and after.
// Can catch the following:
// 1. Honeypots
// 2. Internal Fee Scams
// 3. Buy diversions

contract ToleranceCheckOverride {
    enum PoolType {
        V2,
        V3
    }

    function checkToken(address routerAddress, address tokenAddress, uint24 fee, uint256 tolerance, PoolType poolType)
        external
        returns (bool result)
    {
        if (poolType == PoolType.V2) {
            require(fee == 0, "V2 pool must have fee set as 0");
            IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
            result = false;
            if (tokenAddress == router.WETH()) {
                result = true;
            } else {
                result = swap(routerAddress, tokenAddress, tolerance);
            }
        } else if (poolType == PoolType.V3) {
            IPeripheryImmutableState router = IPeripheryImmutableState(routerAddress);
            result = false;
            if (tokenAddress == router.WETH9()) {
                result = true;
            } else {
                result = swapV3(routerAddress, tokenAddress, fee, tolerance);
            }
        }
    }

    function swap(address routerAddress, address tokenAddress, uint256 tolerance) internal returns (bool result) {
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        //Get tokenAmount estimate (can be skipped to save gas in a lot of cases)
        address[] memory pathBuy = new address[](2);
        uint256[] memory amounts;
        pathBuy[0] = router.WETH();
        pathBuy[1] = tokenAddress;
        IERC20 token = IERC20(tokenAddress);

        uint256 initialEth = address(this).balance;

        amounts = UniswapV2Library08.getAmountsOut(router.factory(), initialEth, pathBuy);
        uint256 buyTokenAmount = amounts[amounts.length - 1];

        //Buy tokens
        uint256 scrapTokenBalance = token.balanceOf(address(this));
        router.swapETHForExactTokens{value: initialEth}(buyTokenAmount, pathBuy, address(this), block.timestamp);
        uint256 tokenAmountOut = token.balanceOf(address(this)) - scrapTokenBalance;

        //Sell token
        require(tokenAmountOut > 0, "Can't sell this.");
        address[] memory pathSell = new address[](2);
        pathSell[0] = tokenAddress;
        pathSell[1] = router.WETH();

        uint256 ethBefore = address(this).balance;
        token.approve(routerAddress, tokenAmountOut);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmountOut, 0, pathSell, address(this), block.timestamp
        );
        uint256 ethOut = address(this).balance - ethBefore;
        result = initialEth - ethOut <= tolerance;
    }

    function swapV3(address routerAddress, address tokenAddress, uint24 fee, uint256 tolerance)
        internal
        returns (bool result)
    {
        ISwapRouter router = ISwapRouter(routerAddress);
        IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        IERC20 TOKEN = IERC20(tokenAddress);

        uint256 initialEth = address(this).balance;
        ISwapRouter.ExactInputSingleParams memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams(
            address(WETH), tokenAddress, fee, address(this), block.timestamp + 1200, initialEth, 0, 0
        );
        uint256 scrapTokenBalance = TOKEN.balanceOf(address(this));
        router.exactInputSingle{value: initialEth}(exactInputSingleParams);
        uint256 tokenReceived = TOKEN.balanceOf(address(this)) - scrapTokenBalance;

        //Sell token
        require(tokenReceived > 0, "Can't sell this");
        uint256 ethBefore = address(this).balance;
        TOKEN.approve(address(router), tokenReceived);
        exactInputSingleParams = ISwapRouter.ExactInputSingleParams(
            address(TOKEN), address(WETH), fee, address(this), block.timestamp + 1200, tokenReceived, 0, 0
        );
        router.exactInputSingle(exactInputSingleParams);
        uint256 ethAfter = address(this).balance + WETH.balanceOf(address(this));
        uint256 ethOut = ethAfter - ethBefore;
        return initialEth - ethOut <= tolerance;
    }

    fallback() external payable {}
}
