/*
    Copyright 2020 Fabrx Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
pragma solidity 0.5.17;

// Libraries
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../util/ZeroCollateralCommon.sol";
import "../util/NumbersList.sol";

// Contracts
import "./OwnerSignersRole.sol";
import "../base/Base.sol";


contract Consensus is Base, OwnerSignersRole {
    using SafeMath for uint256;
    using NumbersList for NumbersList.Values;

    // Has signer address already submitted their answer for (user, identifier)?
    mapping(address => mapping(address => mapping(uint256 => bool))) public hasSubmitted;

    // mapping from signer address, to signerNonce, to boolean.
    // Has the signer already used this nonce?
    mapping(address => mapping(uint256 => bool)) public signerNonceTaken;

    // the address with permissions to submit a request for processing
    address public callerAddress;

    modifier isCaller() {
        require(callerAddress == msg.sender, "Address has no permissions.");
        _;
    }

    function initialize(
        address aCallerAddress, // loans for LoanTermsConsensus, lenders for InterestConsensus
        address aSettingAddress
    ) public isNotInitialized() {
        aCallerAddress.requireNotEmpty("MUST_PROVIDE_LENDER_INFO");

        _initialize(aSettingAddress);

        callerAddress = aCallerAddress;
    }

    function _signatureValid(
        ZeroCollateralCommon.Signature memory signature,
        bytes32 dataHash,
        address expectedSigner
    ) internal view returns (bool) {
        if (!isSigner(expectedSigner)) return false;

        require(
            !signerNonceTaken[expectedSigner][signature.signerNonce],
            "SIGNER_NONCE_TAKEN"
        );

        address signer = ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)),
            signature.v,
            signature.r,
            signature.s
        );
        return (signer == expectedSigner);
    }

    function _getConsensus(NumbersList.Values storage values)
        internal
        view
        returns (uint256)
    {
        require(
            values.isWithinTolerance(settings.maximumTolerance()),
            "RESPONSES_TOO_VARIED"
        );

        return values.getAverage();
    }

    function _validateResponse(
        address signer,
        address user,
        uint256 requestIdentifier,
        uint256 responseTime,
        bytes32 responseHash,
        ZeroCollateralCommon.Signature memory signature
    ) internal {
        require(
            !hasSubmitted[signer][user][requestIdentifier],
            "SIGNER_ALREADY_SUBMITTED"
        );
        hasSubmitted[signer][user][requestIdentifier] = true;

        require(
            responseTime >= now.sub(settings.responseExpiryLength()),
            "RESPONSE_EXPIRED"
        );

        require(_signatureValid(signature, responseHash, signer), "SIGNATURE_INVALID");
        signerNonceTaken[signer][signature.signerNonce] = true;
    }

    function _getChainId() internal view returns (uint256) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
