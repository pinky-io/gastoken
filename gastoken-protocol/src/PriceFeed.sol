// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./Interfaces/IPriceFeed.sol";
import "./Interfaces/IAutomatedFunctionsConsumer.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/BaseMath.sol";
import "./Dependencies/LiquityMath.sol";

/*
* PriceFeed for mainnet deployment, to be connected to Chainlink's live ETH:USD aggregator reference 
* contract.
*
* The PriceFeed uses Chainlink as primary oracle.
*/
contract PriceFeed is Ownable, CheckContract, BaseMath, IPriceFeed {
    using SafeMath for uint256;

    string public constant NAME = "PriceFeed";

    IAutomatedFunctionsConsumer public priceAggregator; // from Chainlink

    // Core Liquity contracts
    address borrowerOperationsAddress;
    address troveManagerAddress;

    // Maximum time period allowed since Chainlink's latest round data timestamp, beyond which Chainlink is considered frozen.
    uint256 public constant TIMEOUT = 14400; // 4 hours: 60 * 60 * 4

    // The last good price seen from an oracle by Liquity
    uint256 public lastGoodPrice;

    // --- Dependency setters ---

    function setAddresses(address _priceAggregatorAddress) external onlyOwner {
        checkContract(_priceAggregatorAddress);

        priceAggregator = IAutomatedFunctionsConsumer(_priceAggregatorAddress);

        // Get an initial price from Chainlink to serve as first reference for lastGoodPrice
        bytes memory chainlinkResponse = _getCurrentChainlinkResponse();

        _storeChainlinkPrice(chainlinkResponse);

        _renounceOwnership();
    }

    // --- Functions ---

    /*
    * fetchPrice():
    * Returns the latest price obtained from the Oracle. Called by Liquity functions that require a current price.
    *
    * Also callable by anyone externally.
    *
    * Non-view function - it stores the last good price seen by Liquity.
    *
    */
    function fetchPrice() external override returns (uint256) {
        // Get current price data from Chainlink
        // temporary mock data for testing purpose (should be done in test file)
        return 20 gwei / 1000;
        // bytes memory chainlinkResponse = _getCurrentChainlinkResponse();

        // if (!_chainlinkIsBroken(chainlinkResponse)) {
        //     return _storeChainlinkPrice(chainlinkResponse);
        // } else {
        //     return lastGoodPrice;
        // }
    }

    // --- Helper functions ---

    function _chainlinkIsBroken(bytes memory _currentResponse) internal pure returns (bool) {
        // Check for non-positive price
        if (_currentResponse.length <= 0) return true;

        return false;
    }

    function _storePrice(uint256 _currentPrice) internal {
        lastGoodPrice = _currentPrice;
        emit LastGoodPriceUpdated(_currentPrice);
    }

    function _storeChainlinkPrice(bytes memory _chainlinkResponse) internal returns (uint256) {
        uint256 price = uint256(bytes32(_chainlinkResponse));
        // scaling down to have a coherent value
        price = price / 10 ** 18;
        _storePrice(price);

        return price;
    }

    // --- Oracle response wrapper functions ---

    function _getCurrentChainlinkResponse() internal returns (bytes memory chainlinkResponse) {
        return priceAggregator.latestResponse();
    }
}
