use starknet::ContractAddress;

use starknet::contract_address::contract_address_const;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use token_sale::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
use token_sale::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

use token_sale::mocks::mock_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait};


fn deploy_contract(name: ByteArray, payment_token_address: ContractAddress) -> (ITokenSaleDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let contract = declare(name).unwrap().contract_class();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let constructor_calldata = array![owner.into(), payment_token_address.into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let token_sale = ITokenSaleDispatcher{contract_address};

    (token_sale, contract_address, owner, payment_token_address)
}

fn deploy_mock_erc20() -> (IERC20Dispatcher, ITestERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let token = IERC20Dispatcher { contract_address };
    let test_token = ITestERC20Dispatcher { contract_address };
    (token, test_token, contract_address)
}

#[test]
fn test_constructor () {
    let (payment_token, _, payment_token_address) = deploy_mock_erc20();
    let (token_sale, _, owner, accepted_payment_token) = deploy_contract("TokenSale", payment_token_address);
    assert!(token_sale.get_owner() == owner, "Owner not set correctly");
    assert!(token_sale.get_accepted_payment_token() == accepted_payment_token, "Accepted payment token not set correctly");
}

#[test]
fn test_check_available_token() {
    // Deploy payment token first
    let (payment_token, _, payment_token_address) = deploy_mock_erc20();
    
    // Deploy TokenSale contract
    let (token_sale, token_sale_contract_address, owner, _) = deploy_contract("TokenSale", payment_token_address);

    let (token, test_token, token_address) = deploy_mock_erc20();

    let available_token = token_sale.check_available_token(token_address);
    assert!(available_token == 0, "Available token should be 0");

    test_token.mint(owner, 1000_u256);

    start_cheat_caller_address(token_address, owner);
    token.approve(token_sale_contract_address, 100_u256);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_sale_contract_address, owner);
    token_sale.deposit_token(token_address, 100_u256, 10_u256);
    stop_cheat_caller_address(token_sale_contract_address);

    let available_after = token_sale.check_available_token(token_address);
    assert!(available_after == 100, "Available token should be 100");
}

#[test]
#[should_panic(expected: ('Unauthorized',))]
fn test_deposit_token_unauthorized() {

    let (_, test_token, token_address) = deploy_mock_erc20();

    let (token_sale, contract_address, owner, _) = deploy_contract("TokenSale", token_address);
    
    test_token.mint(owner, 1000_u256);
    
    let unauthorized_user = contract_address_const::<'unauthorized'>();
    
    start_cheat_caller_address(contract_address, unauthorized_user);
    
    token_sale.deposit_token(token_address, 100_u256, 10_u256);
}

#[test]
fn test_deposit() {
    // Deploy payment token first
    let (payment_token, _, payment_token_address) = deploy_mock_erc20();
    
    let (token_sale, token_sale_contract_address, owner, _) = deploy_contract("TokenSale", payment_token_address);

    let (token, test_token, token_address) = deploy_mock_erc20();

    let amount = 100_u256;
    let price = 10_u256;
    let amount_to_deposit = 10_u256;

    assert!(token.balance_of(owner) == 0, "Owner should have 0 tokens");

    test_token.mint(owner, amount);
    assert!(token.balance_of(owner) == amount, "Owner should have 100 tokens");

    start_cheat_caller_address(token_address, owner);
    token.approve(token_sale_contract_address, amount);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_sale_contract_address, owner);
    token_sale.deposit_token(token_address, amount_to_deposit, price);
    stop_cheat_caller_address(token_sale_contract_address);

    assert!(token_sale.check_available_token(token_address) == amount_to_deposit, "Available token should be 10");
    assert!(token.balance_of(token_sale_contract_address) == amount_to_deposit, "Token sale contract should have 100 tokens");

    start_cheat_caller_address(token_address, owner);
    token.approve(token_sale_contract_address, amount);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_sale_contract_address, owner);
    token_sale.deposit_token(token_address, amount_to_deposit, price);
    stop_cheat_caller_address(token_sale_contract_address);

    assert!(token_sale.check_available_token(token_address) == amount_to_deposit * 2, "Available token should be 20");

    assert!(token.balance_of(token_sale_contract_address) == amount_to_deposit * 2, "Token sale contract should have 200 tokens");
    assert!(token.balance_of(owner) == amount - (amount_to_deposit * 2), "Owner should have 90 tokens");
}

#[test]
fn test_buy_token() {
    // Deploy payment token first
    let (payment_token, payment_test_token, payment_token_address) = deploy_mock_erc20();
    
    let (token_sale, contract_address, owner, _) = deploy_contract("TokenSale", payment_token_address);
    
    let (sell_token, sell_test_token, sell_token_address) = deploy_mock_erc20();
    
    let buyer: ContractAddress = contract_address_const::<'buyer'>();
    let token_amount = 100_u256;
    let token_price = 50_u256;
    let total_payment = token_price * token_amount;
    
    // Mint tokens to owner and buyer
    sell_test_token.mint(owner, 1000_u256);
    payment_test_token.mint(buyer, total_payment);
    
    start_cheat_caller_address(sell_token_address, owner);
    sell_token.approve(contract_address, token_amount);
    stop_cheat_caller_address(sell_token_address);
    
    start_cheat_caller_address(contract_address, owner);
    token_sale.deposit_token(sell_token_address, token_amount, token_price);
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(payment_token_address, buyer);
    payment_token.approve(contract_address, total_payment);
    stop_cheat_caller_address(payment_token_address);
    
    // Buyer purchases tokens
    start_cheat_caller_address(contract_address, buyer);
    token_sale.buy_token(sell_token_address, token_amount);
    stop_cheat_caller_address(contract_address);
    
    // Verify buyer received tokens
    assert!(sell_token.balance_of(buyer) == token_amount, "Buyer should have received tokens");
    
    // Verify contract received payment
    assert!(payment_token.balance_of(contract_address) == total_payment, "Contract should have received payment");
}