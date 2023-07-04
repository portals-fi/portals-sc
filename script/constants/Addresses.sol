// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract Addresses {
    mapping(string => address) private Ethereum;
    mapping(string => address) private Polygon;
    mapping(string => address) private Fantom;
    mapping(string => address) private Avalanche;
    mapping(string => address) private Optimism;
    mapping(string => address) private Arbitrum;
    mapping(string => address) private BNB;

    error NoAddress(string network, string name);

    constructor() {
        Polygon["admin"] = 0x5c883bAef73C7F0e9C5Ee9d6DfaCCd3ed00ACf26;
        Ethereum["admin"] = 0x7cFecFBA73D62125F2eef82A0E0454e4000935bE;
        Fantom["admin"] = 0xC585C45D6538DABc58E7740a07e840a679AB872B;
        Avalanche["admin"] =
            0xB0f6bC7b4D996cC483EA3578585Fa74E71280C53;
        Optimism["admin"] = 0x183a0490C4b5BC5cA8a9eB65F8EE8Fd5B019aD86;
        Arbitrum["admin"] = 0xa7D040C780A84A18DbD8F47a6beCa2aA17A60ea3;
        BNB["admin"] = 0x5199c0E2726C91a13F8d674c6977c765D61716d9;
    }

    function get(string memory network, string memory name)
        public
        view
        returns (address entity)
    {
        if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Polygon"))
        ) {
            entity = Polygon[name];
            require(entity != address(0), "Polygon address not found");
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Ethereum"))
        ) {
            entity = Ethereum[name];
            require(
                entity != address(0), "Ethereum address not found"
            );
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Fantom"))
        ) {
            entity = Fantom[name];
            require(entity != address(0), "Fantom address not found");
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Avalanche"))
        ) {
            entity = Avalanche[name];
            require(
                entity != address(0), "Avalanche address not found"
            );
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Optimism"))
        ) {
            entity = Optimism[name];
            require(
                entity != address(0), "Optimism address not found"
            );
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Arbitrum"))
        ) {
            entity = Arbitrum[name];
            require(
                entity != address(0), "Arbitrum address not found"
            );
        } else if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("BNB"))
        ) {
            entity = BNB[name];
            require(entity != address(0), "BNB address not found");
        } else {
            revert NoAddress(network, name);
        }
    }

    // add this to be excluded from coverage report
    function test() public { }
}
