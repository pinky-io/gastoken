# GasToken

This is the repo for the SP95 project, a DeFi protocol allowing anyone to hedge themselfes against the gas price volatility.
This project was made during the [ETHGlobal Paris 2023 Hackathon](https://ethglobal.com/events/paris2023). 


## Overview

The initial objective was to understand how one can tokenize the gas on an EVM blockchain, as a DeFi primitive to enable ecosystem interoperability. We did a lot of research and decided, as a first step, to create a token pegged to the average price of the gas during the past week. This allow to strongly reduce volatility and unlock interesting use cases such as mid-term hedging and gas costs anticipation for the bigger gas consumers. With this protocol, one could also create interesting products such as gas volatility policies.

Here is the content of our project:
- [**The GasToken Protocol**](gastoken-protocol/), a Liquity fork allowing one to mint the GasToken as a colateralized debt in ETH,
- [**A Database**](db/) retrieving the historical gas price per block,
- [**The GasToken Oracle**](https://github.com/pinky-io/base-fee-average-oracle), which provides the average gas price on-chain,
- [**A market-risk Simulation**](protocol-simulation/) to better understand how the gas volatility can impact our protocol,
- [**A frontend Client**](gastoken-client/) to easily use our protocol,
- [**A EIP4337-ready Paymaster**](gastoken-paymaster/) that can redeem the GasToken and pay the gas fees for the users.

## The Team

- [@bibop_eth](https://twitter.com/bipbop_eth), Solidity dev
- [@HichRPTG](https://twitter.com/HichRPTG), Quant Researcher
- [@sinane_eth](https://twitter.com/sinane_eth), Web3 No-code tools builder
- [Riad](https://www.linkedin.com/in/riad-eddahabi/), Front-end Dev
- [@bastienchamp](https://twitter.com/bastienchamp), Product Owner
