// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamond Standard: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import "./libraries/LibDiamond.sol";
import "./interfaces/IDiamondLoupe.sol";
import "./interfaces/IDiamondCut.sol";
import "./interfaces/IERC173.sol";
import "./interfaces/IERC165.sol";

contract Diamond {

    constructor(IDiamondCut.FacetCut[] memory _diamondCut, bytes memory data, address owner) payable {
        // -----------------------------------------------------------------------------------------------------------
        // Builtin Facets
        // ------------------------------------------------------------------------------------------------------------

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        // -----------------------------------------------------------------------------------------------------------
        // Dimaond Cuts For Builtin Facets
        // ------------------------------------------------------------------------------------------------------------

        IDiamondCut.Facet[] memory builtinDiamondCut = new IDiamondCut.Facet[](3);

        // adding diamondCut function
        diamondCut[0].facetAddress = address(diamondCutFacet);
        diamondCut[0].functionSelectors = new bytes4[](1);
        diamondCut[0].functionSelectors[0] = DiamondCutFacet.diamondCut.selector;

        // adding diamond loupe functions
        diamondCut[1].facetAddress = address(diamondLoupeFacet);
        diamondCut[1].functionSelectors = new bytes4[](5);
        diamondCut[1].functionSelectors[0] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondCut[1].functionSelectors[1] = DiamondLoupeFacet.facets.selector;
        diamondCut[1].functionSelectors[2] = DiamondLoupeFacet.facetAddress.selector;
        diamondCut[1].functionSelectors[3] = DiamondLoupeFacet.facetAddresses.selector;
        diamondCut[1].functionSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        // adding ownership functions
        diamondCut[2].facetAddress = address(ownershipFacet);
        diamondCut[2].functionSelectors = new bytes4[](2);
        diamondCut[2].functionSelectors[0] = OwnershipFacet.transferOwnership.selector;
        diamondCut[2].functionSelectors[1] = OwnershipFacet.owner.selector;

        // cut the builtin facets
        LibDiamondCut.diamondCut(builtinDiamondCut, address(0), new bytes(0));


        // -----------------------------------------------------------------------------------------------------------
        // adding ERC165 data
        // ------------------------------------------------------------------------------------------------------------

        // ERC165
        ds.supportedInterfaces[IERC165.supportsInterface.selector] = true;

        // DiamondCut
        ds.supportedInterfaces[DiamondCutFacet.diamondCut.selector] = true;

        // DiamondLoupe
        bytes4 interfaceID = IDiamondLoupe.facets.selector ^
            IDiamondLoupe.facetFunctionSelectors.selector ^
            IDiamondLoupe.facetAddresses.selector ^
            IDiamondLoupe.facetAddress.selector;
        ds.supportedInterfaces[interfaceID] = true;

        // ERC173
        ds.supportedInterfaces[IERC173.transferOwnership.selector ^ IERC173.owner.selector] = true;

        // -----------------------------------------------------------------------------------------------------------
        // Cut And Execute
        // ------------------------------------------------------------------------------------------------------------

        // execute the provided cuts if any
        if (_diamondCut.length > 0 || data.length > 0) {
            address facet = ds.selectorToFacetAndPosition[data.sig].facetAddress;
            require(facet != address(0), "Diamond: Function does not exist");
            LibDiamondCut.diamondCut(_diamondCut, facet, data);
        }


        // -----------------------------------------------------------------------------------------------------------
        // Set Owner at the end so that the data call (above) can still perform is owner == address(0)
        // ------------------------------------------------------------------------------------------------------------

        LibDiamond.setContractOwner(owner);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}
