//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "./BnbDividendTracker.sol";

contract DustToken is ERC20, Ownable {
    // Fee Percentages
    uint256 public liqFeeBuy;
    uint256 public liqFeeSell;
    uint256 public bnbFee;
    uint256 public marketingFee;
    uint256 public devFee;
    uint256 public constant minSwap = 500000 ether;
    // Global amounts held
    uint256 public liqAmount;
    uint256 public marketingAmount;
    uint256 public devAmount;
    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;
    // Constants
    uint256 public constant DIVISOR = 10000;
    // Lock for swaps happening
    bool public swapping;
    address public devAddress;
    address public marketingAddress;
    address public constant deadWallet =
        0x000000000000000000000000000000000000dEaD;
    // Router
    IUniswapV2Router02 public uniswapV2Router;
    BNBDividendTracker public dividendToken;
    address public mainPair;

    mapping(address => bool) public isPair;
    mapping(address => bool) public feeExcluded;

    event LogEvent(string data);
    event AddedPair(address indexed _pair);
    event UpdatedFees(
        uint256 _bnb,
        uint256 _liqSell,
        uint256 _liqBuy,
        uint256 _marketing,
        uint256 _dev
    );
    event UpdateDividendTracker(
        address indexed newAddress,
        address indexed oldAddress
    );
    event UpdateMarketing(address _new, address _old);
    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("Spacedust Bnb", "DUST") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x05E61E0cDcD2170a76F9568a110CEe3AFdD6c46f
        );
        address _swapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        mainPair = _swapPair;
        feeExcluded[owner()] = true;

        liqFeeBuy = 300;
        liqFeeSell = 200;
        bnbFee = 800;
        marketingFee = 100;
        devFee = 100;

        devAddress = msg.sender;
        marketingAddress = msg.sender;

        dividendToken = new BNBDividendTracker();
        dividendToken.excludeFromDividends(_swapPair);
        dividendToken.excludeFromDividends(address(dividendToken));
        dividendToken.excludeFromDividends(owner());
        dividendToken.excludeFromDividends(deadWallet);
        dividendToken.excludeFromDividends(address(this));
        dividendToken.excludeFromDividends(address(0));
        dividendToken.excludeFromDividends(address(uniswapV2Router));
        _mint(msg.sender, 100000000000 ether); // 100 BILLION ETHER TO OWNER
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 currentBalance = balanceOf(address(this));
        bool canSwap = currentBalance >= minSwap;
        if (!swapping && !isPair[from] && from != owner() && to != owner()) {
            swapping = true;
            swapRewardsAndDistribute(currentBalance);
            swapping = false;
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        try dividendToken.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendToken.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping) {
            uint256 gas = gasForProcessing;

            try dividendToken.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }
        uint256 liquidityFee;
        uint256 rewardFee;
        uint256 marketing;
        uint256 dev;
        // TRY TO TAX ONLY SELLS AND BUYS THIS ALSO TAXES ADDING LIQUIDITY UNFORTUNATELY.
        // THERE'S NO WAY AROUND THIS UNLESS LIQUIDITY IS ADDED MANUALLY (NOT RECOMMENDED)
        if (!feeExcluded[from] && !swapping) {
            // BUY
            if (isPair[from])
                (amount, liquidityFee, rewardFee) = taxBuy(amount);
            // SELL
            if (isPair[to])
                (amount, liquidityFee, rewardFee, marketing, dev) = taxSell(
                    amount
                );
            if (liquidityFee + rewardFee + marketing + dev > 0) {
                super._transfer(
                    from,
                    address(this),
                    liquidityFee + rewardFee + marketing + dev
                );
                liqAmount += liquidityFee;
                marketingAmount += marketing;
                devAmount += dev;
            }
        }
        super._transfer(from, to, amount);
    }

    function addPair(address _pairAddress) external onlyOwner {
        require(!isPair[_pairAddress], "Already added");
        isPair[_pairAddress] = true;

        if (_pairAddress != mainPair)
            dividendToken.excludeFromDividends(_pairAddress);
        emit AddedPair(_pairAddress);
    }

    function buyFee() public view returns (uint256 _fee) {
        _fee = liqFeeBuy + bnbFee;
    }

    function sellFee() public view returns (uint256 _fee) {
        _fee = liqFeeSell + bnbFee + marketingFee + devFee;
    }

    function taxBuy(uint256 amount)
        private
        returns (
            uint256 _newAmount,
            uint256 _liq,
            uint256 _bnb
        )
    {
        _bnb = (bnbFee * amount) / DIVISOR;
        _liq = (liqFeeBuy * amount) / DIVISOR;
        uint256 totalFee = _bnb + _liq;
        _newAmount = amount - totalFee;
    }

    function taxSell(uint256 amount)
        private
        returns (
            uint256 _newAmount,
            uint256 _liq,
            uint256 _bnb,
            uint256 _marketing,
            uint256 _dev
        )
    {
        _bnb = (bnbFee * amount) / DIVISOR;
        _liq = (liqFeeBuy * amount) / DIVISOR;
        _dev = (devFee * amount) / DIVISOR;
        _marketing = (marketingFee * amount) / DIVISOR;
        uint256 totalFee = _bnb + _liq + _marketing + _dev;
        _newAmount = amount - totalFee;
    }

    //PLEASE CHANGE BACK TO PRIVATE#3
    function swapRewardsAndDistribute(uint256 currentBalance) public {
        uint256 bnb = currentBalance - liqAmount - marketingAmount - devAmount;
        uint256 half = liqAmount / 2;
        uint256 liqOtherHalf = liqAmount - half;
        swapForEth(currentBalance - liqOtherHalf);
        uint256 ethBalance = address(this).balance;
        bool txSuccess = false;
        uint256[4] memory balances = getPercentages(
            [bnb, half, marketingAmount, devAmount],
            currentBalance - liqOtherHalf,
            ethBalance
        );
        //sendToDividends( balances[0]);
        if (balances[0] > 0) {
            (txSuccess, ) = payable(address(dividendToken)).call{
                value: balances[0]
            }("");
            if (txSuccess) {
                ethBalance -= balances[0];
                txSuccess = false;
            }
        }
        //makeLiquidity(balances[1]);
        if (balances[1] > 0) {
            addLiquidity(balances[1], liqOtherHalf);
            ethBalance -= balances[1];
            liqAmount = 0;
        }
        // MarketingFunds Transfer
        if (balances[2] > 0) {
            (txSuccess, ) = payable(marketingAddress).call{value: balances[2]}(
                ""
            );
            if (txSuccess) {
                marketingAmount = 0;
                ethBalance -= balances[2];
                txSuccess = false;
            }
        }
        // DevFunds Transfer
        if (balances[3] > 0) {
            (txSuccess, ) = payable(devAddress).call{value: ethBalance}("");
            if (txSuccess) {
                devAmount = 0;
            }
        }
    }

    //PLEASE CHANGE BACK TO PRIVATE#1
    function swapForEth(uint256 amount) public {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), amount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    //PLEASE CHANGE BACK TO PRIVATE#2
    function getPercentages(
        uint256[4] memory percentages,
        uint256 base,
        uint256 multiplier
    ) public pure returns (uint256[4] memory _finalValues) {
        for (uint8 i = 0; i < percentages.length; i++) {
            _finalValues[i] = (percentages[i] * multiplier) / base;
        }
    }

    function setFees(
        uint256 _bnb,
        uint256 _liqSell,
        uint256 _liqBuy,
        uint256 _marketing,
        uint256 _dev
    ) external onlyOwner {
        require(_bnb + _liqSell + _marketing + _dev <= 4000, "High fees");
        require(_bnb + _liqBuy <= 4000, "High fees");
        bnbFee = _bnb;
        liqFeeBuy = _liqBuy;
        liqFeeSell = _liqSell;
        marketingFee = _marketing;
        devFee = _dev;
        emit UpdatedFees(_bnb, _liqSell, _liqBuy, _marketing, _dev);
    }

    function setMarketingWallet(address payable _marketingWallet)
        external
        onlyOwner
    {
        require(_marketingWallet != address(0), "use Marketing");
        emit UpdateMarketing(_marketingWallet, marketingAddress);
        marketingAddress = _marketingWallet;
    }

    function addLiquidity(uint256 ethAmount, uint256 tokenAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, //whatever slippage dictates
            0, //whatever slippage dictates
            address(0), // "burn" immediately
            block.timestamp
        );
    }

    function setDevAddress(address payable _devAddress) external onlyOwner {
        require(_devAddress != address(0), "Pay the dev please");
        devAddress = _devAddress;
    }

    function claim() external {
        dividendToken.processAccount(payable(msg.sender), false);
    }

    /// @notice Updates the dividend tracker's address
    /// @param newAddress New dividend tracker address
    function updateDividendTracker(address newAddress) public onlyOwner {
        require(
            newAddress != address(dividendTracker),
            "DustToken: The dividend tracker already has that address"
        );

        BNBDividendTracker newDividendTracker = BNBDividendTracker(
            payable(newAddress)
        );

        require(
            newDividendTracker.owner() == address(this),
            "DustToken: The new dividend tracker must be owned by the deployer of the contract"
        );

        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(owner());
        newDividendTracker.excludeFromDividends(address(uniswapV2Router));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    /// @notice Updates the uniswapV2Router's address
    /// @param newAddress New uniswapV2Router's address
    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "DustToken: The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    /// @notice Excludes address from fees
    /// @param newAddress New uniswapV2Router's address
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "DustToken: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }
    // function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner
    // function blacklistAddress(address account, bool value) external onlyOwner
    // function updateGasForProcessing(uint256 newValue) public onlyOwner **
    // function updateClaimWait(uint256 claimWait) external onlyOwner*
    // function isExcludedFromFees(address account) public view returns(bool)
    // function withdrawableDividendOf(address account) public view returns(uint256)
}
