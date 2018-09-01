pragma solidity >=0.4.18;// Incompatible compiler version... please select one stated within pragma solidity or use different oraclizeAPI version

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

  address public owner;

  /**
  * @dev The Ownable constructor sets the original `owner` of the contract to the sender
  * account.
  */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
  * @dev Throws if called by any account other than the owner.
  */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
  * @dev Allows the current owner to transfer control of the contract to a newOwner.
  * @param newOwner The address to transfer ownership to.
  */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    owner = newOwner;
  }

}

contract SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract StateSwitchable is Ownable {

  enum State {
    Preparing,
    Sale,
    Paused,
    Finished
  }

  State public state;

  event StartSale();
  event PauseSale();
  event ResumeSale();
  event FinishSale();

  modifier whenNotStarted() {
    require(state == State.Preparing);
    _;
  }

  modifier whenStarted() {
    require(state == State.Sale || state == State.Paused);
    _;
  }

  modifier whenPaused() {
    require(state == State.Paused);
    _;
  }

  modifier whenUnPaused() {
    require(state == State.Sale);
    _;
  }

  // administrative functions
  function start() public onlyOwner whenNotStarted {
    state = State.Sale;
    StartSale();
  }

  function pause() public onlyOwner whenUnPaused {
    state = State.Paused;
    PauseSale();
  }

  function resume() public onlyOwner whenPaused {
    state = State.Sale;
    ResumeSale();
  }

  function finalize() public onlyOwner whenStarted {
    state = State.Finished;
    FinishSale();
  }
}

contract BWCToken is Ownable {

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  string public constant name = "BWCToken";
  string public constant symbol = "BWC";
  uint public constant maxSupply = 1000000000 * (10 ** 18);

  uint public totalSupply;
  bool public mintingFinished = false;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    balances[msg.sender] = balances[msg.sender] - _value;
    balances[_to] = balances[_to] + _value;
    //assert(balances[_to] >= _value); no need to check, since mint has limited hardcap
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function balanceOf(address _owner) constant public returns (uint256 balance) {
    return balances[_owner];
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from] - _value;
    balances[_to] = balances[_to] + _value;
    //assert(balances[_to] >= _value); no need to check, since mint has limited hardcap
    allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value;
    Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint256 _value) public returns (bool) {
    //NOTE: To prevent attack vectors like the one discussed here:
    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729,
    //clients SHOULD make sure to create user interfaces in such a way
    //that they set the allowance first to 0 before setting it to another value for the same spender.

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  function mint(address _to, uint256 _value) onlyOwner canMint public returns (bool) {
    require(_to != address(0));
    require(maxSupply > totalSupply + _value);
    balances[_to] = balances[_to] + _value;
    totalSupply = totalSupply + _value;
    Mint(_to, _value);
    return true;
  }

  function finishMinting() onlyOwner public returns (bool) {
    mintingFinished = true;
    MintFinished();
    return true;
  }

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public returns (bool) {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure
    balances[msg.sender] = balances[msg.sender] - _value;
    totalSupply = totalSupply - _value;
    Burn(msg.sender, _value);
    return true;
  }

  function burnFrom(address _from, uint256 _value) public returns (bool success) {
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    balances[_from] = balances[_from] - _value;
    allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value;
    totalSupply = totalSupply - _value;
    Burn(_from, _value);
    return true;
  }

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  event Mint(address indexed to, uint256 amount);

  event MintFinished();

  event Burn(address indexed burner, uint256 value);

}

contract BWCCrowdsale is Ownable, usingOraclize, SafeMath, StateSwitchable {
  struct Buyer {
    address addr;
    uint amount;
  }

  // hardCap in usd
  uint public constant HARDCAP_USD = 100000;
  // softCap in usd
  uint public constant SOFTCAP_USD = 15000;
  // maximum token supply
  uint public constant MAX_TOKEN_SUPPLY = 1000000000 * (10**18);

  BWCToken public token;
  mapping (bytes32 => Buyer) public contributors;

  uint public ethRate;
  uint public tokenSold;
  uint public usdRaised;

  // events
  event OrderPlaced(bytes32 _queryId, address _address, uint _amount);
  event TokenCredited(bytes32 _queryId, address _address, uint _amount, uint _ethRate, uint _tokenAmount);

  modifier isOraclize() {
    require(msg.sender == oraclize_cbAddress());
    _;
  }

  function BWCCrowdsale(BWCToken _token) public {
    token = _token;
    state = State.Preparing;
  }

  /**
   * @dev handle Oraclize callback with eth price and mint token
   */
  function __callback(bytes32 myId, string result) public isOraclize whenUnPaused {

    ethRate = parseInt(result, 2);  // ethRate = realPrice * 100 due to float value
    uint256 amountUSD = contributors[myId].amount * ethRate / 100;  // amount * 10 ^ 18
    uint256 amountToken = amountUSD * 100;
    tokenSold = add(tokenSold, amountToken);
    usdRaised = add(usdRaised, div(amountUSD, 10 ** 18));

    token.mint(contributors[myId].addr, amountToken);

    TokenCredited(myId, contributors[myId].addr, contributors[myId].amount, ethRate, amountToken);
  }

  /**
   * @dev Deposit Ether and Request ETH/USD price
   */
  function buy() public payable whenUnPaused {
    require(MAX_TOKEN_SUPPLY >= (tokenSold + msg.value * ethRate * 100 / 100));
    require(HARDCAP_USD >= (usdRaised + msg.value * ethRate / 100));
    // request usd price
    bytes32 queryId = oraclize_query("URL", "json(https://api.gdax.com/products/ETH-USD/ticker).price");
    contributors[queryId] = Buyer(msg.sender, msg.value);

    OrderPlaced(queryId, msg.sender, msg.value);
  }
}