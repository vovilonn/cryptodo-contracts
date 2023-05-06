// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IExecutable {
    function stake(uint256 amount) external;

    function burn(uint256 amount) external;
}

contract MultiSigOwner is Ownable {
    address[] private owners;
    mapping(address => uint256) private weights;
    uint256 private totalWeight;
    uint256 private quorum;
    address private targetContract;
    IExecutable private executableInstance;

    mapping(address => mapping(bytes32 => bool)) private confirmedTransactions;

    constructor(
        address[] memory _owners,
        uint256[] memory _weights,
        uint256 _quorum,
        address _targetContract
    ) {
        require(_owners.length > 0, "Owners cannot be empty");
        require(
            _owners.length == _weights.length,
            "Owners and weights arrays should have the same length"
        );
        require(_quorum > 0 && _quorum <= 100, "Invalid quorum");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            uint256 weight = _weights[i];

            require(owner != address(0), "Invalid owner");
            require(weight > 0, "Invalid weight");
            require(weights[owner] == 0, "Duplicate owner");

            owners.push(owner);
            weights[owner] = weight;
            totalWeight += weight;
        }

        quorum = _quorum;
        targetContract = _targetContract;
        executableInstance = IExecutable(_targetContract);
    }

    function addOwner(address newOwner, uint256 weight) public onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        require(weight > 0, "Invalid weight");
        require(weights[newOwner] == 0, "Duplicate owner");

        owners.push(newOwner);
        weights[newOwner] = weight;
        totalWeight += weight;
    }

    function removeOwner(address ownerToRemove) public onlyOwner {
        require(weights[ownerToRemove] > 0, "Not an owner");

        for (uint i = 0; i < owners.length - 1; i++) {
            if (owners[i] == ownerToRemove) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }

        owners.pop();
        totalWeight -= weights[ownerToRemove];
        weights[ownerToRemove] = 0;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function isConfirmed(bytes32 txHash) public view returns (bool) {
        uint256 weight = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmedTransactions[owners[i]][txHash]) {
                weight += weights[owners[i]];
            }
        }
        return weight * 100 >= totalWeight * quorum;
    }

    function confirm(bytes32 txHash) public {
        require(weights[msg.sender] > 0, "Not an owner");
        require(
            !confirmedTransactions[msg.sender][txHash],
            "Transaction already confirmed"
        );

        confirmedTransactions[msg.sender][txHash] = true;
    }

    function revoke(bytes32 txHash) public {
        require(weights[msg.sender] > 0, "Not an owner");
        require(
            confirmedTransactions[msg.sender][txHash],
            "Transaction not confirmed"
        );

        confirmedTransactions[msg.sender][txHash] = false;
    }

    // =========

    function claim(
        uint256 nonce,
        uint256 amount
    ) external whenConfirmed(nonce, amount) {
        executableInstance.stake(amount);
    }

    function burn(
        uint256 nonce,
        uint256 amount
    ) external whenConfirmed(nonce, amount) {
        executableInstance.burn(amount);
    }

    // =========

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function setQuorum(uint256 _quorum) public onlyOwner {
        require(_quorum > 0 && _quorum <= 100, "Invalid quorum");
        quorum = _quorum;
    }

    function setWeight(address owner, uint256 weight) public onlyOwner {
        require(weights[owner] > 0, "Invalid owner");
        require(weight > 0, "Invalid weight");

        totalWeight = totalWeight - weights[owner] + weight;
        weights[owner] = weight;
    }

    function getWeight(address owner) public view returns (uint256) {
        require(weights[owner] > 0, "Invalid owner");
        return weights[owner];
    }

    function getTotalWeight() public view returns (uint256) {
        return totalWeight;
    }

    modifier whenConfirmed(uint256 nonce, uint256 amount) {
        bytes32 txHash = keccak256(abi.encodePacked(nonce, amount));
        require(
            !confirmedTransactions[msg.sender][txHash],
            "Transaction already confirmed"
        );
        confirmedTransactions[msg.sender][txHash] = true;
        if (isConfirmed(txHash)) {
            _;
            delete confirmedTransactions[msg.sender][txHash];
        }
    }
}
