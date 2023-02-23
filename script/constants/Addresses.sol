// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract Addresses {
    mapping(string => address) private Ethereum;
    mapping(string => address) private Polygon;
    mapping(string => address) private Fantom;

    constructor() {
        Polygon["admin"] = 0x5c883bAef73C7F0e9C5Ee9d6DfaCCd3ed00ACf26;
        Ethereum["admin"] = 0x7cFecFBA73D62125F2eef82A0E0454e4000935bE;
        Fantom["admin"] = 0xC585C45D6538DABc58E7740a07e840a679AB872B;
        Polygon["collector"] =
            0x508ee1b661c7DeE089A5b5c3fD234f1058F03c38;
        Ethereum["collector"] =
            0xFBD4C3D8bE6B15b7cf428Db2838bb44C0054fCd2;
        Fantom["collector"] =
            0x9144439a1d4d5Fb371C491101045815F32150444;
        Ethereum["zeroEx"] =
            0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
        Ethereum["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
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
        }
        if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Ethereum"))
        ) {
            entity = Ethereum[name];
            require(
                entity != address(0), "Ethereum address not found"
            );
        }
        if (
            keccak256(abi.encodePacked(network))
                == keccak256(abi.encodePacked("Fantom"))
        ) {
            entity = Fantom[name];
            require(entity != address(0), "Fantom address not found");
        }
    }
}
