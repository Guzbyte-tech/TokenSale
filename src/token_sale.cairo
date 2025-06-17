#[starknet::contract]
mod TokenSale {
    use starknet::{ContractAddress, get_contract_address, get_caller_address, ClassHash};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry};

    use crate::interfaces::itoken_sale::ITokenSale;
    use crate::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        pub accepted_payment_token: ContractAddress,
        token_price: Map<ContractAddress,u256>,
        pub owner: ContractAddress,
        tokens_available_for_sale: Map<ContractAddress, u256>,

        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, accepted_payment_token: ContractAddress) {
        self.owner.write(owner);
        self.accepted_payment_token.write(accepted_payment_token);
    }

    #[abi(embed_v0)]
    impl TokenSaleImpl of ITokenSale<ContractState> {
        fn check_available_token(self: @ContractState, token_address: ContractAddress) -> u256 {
            let token = IERC20Dispatcher { contract_address: token_address };
            let this_address = get_contract_address();
            token.balance_of(this_address)
        }

        fn deposit_token(ref self: ContractState, token_address: ContractAddress, amount: u256, token_price: u256) {
            let caller = get_caller_address();
            let this_contract = get_contract_address();
            assert(caller == self.owner.read(), 'Unauthorized');

            let token = IERC20Dispatcher { contract_address: token_address };
            let balance = token.balance_of(caller);
            assert(balance >= amount, 'insufficient balance');

            let transfer = token.transfer_from(caller, this_contract, amount);
            assert(transfer, 'transfer failed');

            // Get current amount and price
            let current_amount = self.tokens_available_for_sale.entry(token_address).read();
            let existing_price = self.token_price.entry(token_address).read();

            // If it's a new token (current_amount == 0), write price
            if current_amount == 0 {
                self.token_price.entry(token_address).write(token_price);
            } else if existing_price != token_price {
                // If already deposited, ensure price is not changed unexpectedly
                assert!(existing_price == token_price, "Token already exists with different price");
            }

            // Add to current balance
            let new_amount = current_amount + amount;
            self.tokens_available_for_sale.entry(token_address).write(new_amount);
        }

        fn buy_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let available = self.tokens_available_for_sale.entry(token_address).read();
            assert!(available >= amount, "not enough tokens available");

            let buyer = get_caller_address();
            let payment_token = IERC20Dispatcher { contract_address: self.accepted_payment_token.read() };
            let token_to_buy = IERC20Dispatcher { contract_address: token_address };

            let price_per_token = self.token_price.entry(token_address).read();
            let total_price = price_per_token * amount;

            let buyer_balance = payment_token.balance_of(buyer);
            assert!(buyer_balance >= total_price, "insufficient funds");

            let transfer = payment_token.transfer_from(buyer, get_contract_address(), total_price);
            assert!(transfer, "payment transfer failed");

            let token_transfer = token_to_buy.transfer(buyer, amount);
            assert!(token_transfer, "token transfer failed");

            self.tokens_available_for_sale.entry(token_address).write(available - amount);
        }


        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(get_caller_address() == self.owner.read(), 'Unauthorized');
            self.upgradeable.upgrade(new_class_hash);
        }

        fn get_owner (self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn set_owner(ref self:ContractState, new_owner: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Unauthorized');
            self.owner.write(new_owner);
        }

        fn get_accepted_payment_token(self: @ContractState) -> ContractAddress {
            self.accepted_payment_token.read()
        }
    }
}
