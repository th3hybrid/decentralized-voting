-include .env

.PHONY: all test clean deploy

update:; forge update

build:; forge build

test :; forge test 

format :; forge fmt


NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network base-sepolia,$(ARGS)),--network base-sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployVoting.s.sol:DeployVoting $(NETWORK_ARGS)
