-include .env

build:; forge build
test:; forge test

deploy-sepolia-test:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url ${SEPOLIA_RPC_URL} --account MetaMaskTestAcc --sender ${MetaMaskTestAccPubKey} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-base-sepolia-test:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url ${BASE_SEP_RPC_URL} --account MetaMaskTestAcc --sender ${MetaMaskTestAccPubKey} --broadcast -vvvv