use starknet::ContractAddress;

use starknet::contract_address::contract_address_const;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use token_sale::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
use token_sale::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

use token_sale::mocks::mock_erc20::{ITestERC20Dispatcher, ITestERC20DispatcherTrait};


fn deploy_contract(name: ByteArray) -> (ITokenSaleDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let contract = declare(name).unwrap().contract_class();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let accepted_payment_token = contract_address_const::<'strk'>();
    let constructor_calldata = array![owner.into(), accepted_payment_token.into()];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let token_sale = ITokenSaleDispatcher{contract_address};

    (token_sale, contract_address, owner, accepted_payment_token)
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
    let (token_sale, _, owner, accepted_payment_token) = deploy_contract("TokenSale");
    assert!(token_sale.get_owner() == owner, "Owner not set correctly");
    assert!(token_sale.get_accepted_payment_token() == accepted_payment_token, "Accepted payment token not set correctly");
}

#[test]
fn test_check_available_token() {
    // Deploy TokenSale contract
    let (token_sale, token_sale_contract_address, owner, _) = deploy_contract("TokenSale");

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
fn test_deposit() {
    let (token_sale, token_sale_contract_address, owner, _) = deploy_contract("TokenSale");

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

    let (token_sale, contract_address, owner, _) = deploy_contract("TokenSale");
    
    let (sell_token, sell_test_token, sell_token_address) = deploy_mock_erc20();
    let (payment_token, payment_test_token, payment_token_address) = deploy_mock_erc20();
    
    let buyer: ContractAddress = contract_address_const::<'buyer'>();
    let token_amount = 100_u256;
    let token_price = 50_u256;
    
    // Mint tokens to owner and buyer
    sell_test_token.mint(owner, 1000_u256);
    payment_test_token.mint(buyer, token_price);
    
    // Owner approves and deposits tokens for sale
    start_cheat_caller_address(sell_token_address, owner);
    sell_token.approve(contract_address, token_amount);
    stop_cheat_caller_address(sell_token_address);
    
    start_cheat_caller_address(contract_address, owner);
    token_sale.deposit_token(sell_token_address, token_amount, token_price);
    stop_cheat_caller_address(contract_address);
    
    // Buyer approves payment
    start_cheat_caller_address(payment_token_address, buyer);
    payment_token.approve(contract_address, token_price);
    stop_cheat_caller_address(payment_token_address);
    
    // Buyer purchases tokens
    start_cheat_caller_address(contract_address, buyer);
    token_sale.buy_token(sell_token_address, token_amount);
    stop_cheat_caller_address(contract_address);
    
    // // Verify buyer received tokens
    // assert!(sell_token.balance_of(buyer) == token_amount, "Buyer should have received tokens");
    
    // // Verify contract received payment
    // assert!(payment_token.balance_of(contract_address) == token_price, "Contract should have received payment");

}