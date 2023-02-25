Frenai Token
A ERC20 compliant token that implements taxes and liquidity pools. The smart contract is built with the OpenZeppelin Contracts library, which provides implementation of ERC20 standards.

Table of Contents
Overview
Token Features
Deployment
Usage
License
Overview

The Frenai Token smart contract is written in Solidity, version 0.8.0. The contract implements taxes on transfers and liquidity pools to ensure the stability of the token's value.

The contract owner can set the tax rates for buying and selling. The contract also has four designated wallets to receive the collected taxes. These wallets are liquidity, team, development, and marketing wallets. The tax collected is distributed among these wallets according to the predefined percentage.

Additionally, the contract maintains a target price to determine the token's value. This target price can be set by the contract owner during deployment. The contract uses Chainlink's price feed oracle to fetch the latest market price.

Token Features
ERC20 compliance
Taxes on buy and sell transactions
Liquidity pool
Four designated wallets for collecting taxes
Target price for the token
Price feed oracle integration
Deployment
The contract is deployed using Solidity compiler version 0.8.0 or later. It requires the OpenZeppelin Contracts and Chainlink's price feed aggregator interfaces.

During deployment, the contract owner must provide the initial supply of tokens and the target price for the token. The initial supply is set to 100,000,000 tokens, and the target price is set to the input value.

The address of the price feed aggregator contract on the Ethereum mainnet must also be provided.

Usage
The Frenai Token contract can be used like any ERC20 token. Users can buy and sell tokens and transfer tokens between wallets. However, taxes are applied on buy and sell transactions.

The contract owner can set the tax rates for buying and selling transactions. The owner can also set the percentage of taxes that go to each designated wallet.

License
The Frenai Token contract is released under the MIT License.



