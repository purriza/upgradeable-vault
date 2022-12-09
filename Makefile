-include .env

all: remove install update clean build

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add .

# Install dependencies
install :; forge install foundry-rs/forge-std@v1.0.0 --no-commit && openzeppelin/openzeppelin-contracts --no-commit && forge install openzeppelin/openzeppelin-contracts-upgradeable --no-commit && forge install safe-global/safe-contracts@main --no-commit && forge install Uniswap/v2-periphery --no-commit && forge install Uniswap/v2-core --no-commit && forge install LayerZero-Labs/solidity-examples@main --no-commit

# Update dependencies
update :; forge update

# Clean artifacts
clean :; forge cl

# Build the project (&& FOUNDRY_PROFILE=0_5_x forge build)
build :; forge build 

# Run tests
tests :; forge test

snapshot :; forge snapshot