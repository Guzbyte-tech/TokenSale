use starknet::ContractAddress;

#[starknet::interface]
pub trait ITestERC20<TContractState> {
    fn mint (ref self: TContractState, recipient: ContractAddress, amount:u256) -> bool;
}

#[starknet::contract]
pub mod MockERC20 {
    use ERC20Component::InternalTrait;
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    
    component!(path: ERC20Component, storage: erc20, event:ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("MockERC20", "MKTOKEN");
    }
    
    #[abi(embed_v0)]
    impl TestERCImpl of super::ITestERC20<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.erc20.mint(recipient, amount);
            true
        }
    }
}