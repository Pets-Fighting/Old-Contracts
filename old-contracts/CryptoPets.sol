// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 *  CryptoPets objects are defined here, as ERC721, with only the image url as tokenURI
 *  All other traits, like, HP(Hit Point), MP(Mana Point), EX(Experience) will defined through mappings
 */
contract CryptoPets is ERC721URIStorage{
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // shared attributes of all pets
    string[] public petOptions = [
        'https://i.ibb.co/St9zqL0/image.png',
        'https://i.ibb.co/N9b7vft/1.png',
        'https://i.ibb.co/Vw2450y/2.png',
        'https://i.ibb.co/wyGH3V3/3.png',
        'https://i.ibb.co/W0q1x1D/4.png',
        'https://i.ibb.co/KwPH4J2/5.png'
    ]; // all different pet kinds, with different probability to get
    mapping(address => bool) public createPetsAlready; // if current user already created one pet, every single user can only create one pet
    mapping(uint256 => uint256) public requiredEX; // required EX to upgrade pets' level
    
    // attributes of specific pet
    mapping(uint256 => uint256) public HP; // HP(Hit Point) of corresponding pet token id
    mapping(uint256 => uint256) public attackLow; // minimum harm for normal attack
    mapping(uint256 => uint256) public attackHigh; // supreme harm for normal attack
    mapping(uint256 => uint256) public MP; // MP(Mana Point) of corresponding pet token id(comprehensive force value)
    mapping(uint256 => uint256) public EX; // EX(Experience) of corresponding pet token id
    mapping(uint256 => uint256) public level; // level of corresponding pet token id

    event PetsBirth(address indexed _owner, uint256 _rand, uint256 _petIndex, string _petType);
    event PetsFight(uint256 _tokenIdOne, uint256 _tokenIdTwo, uint256 _winner, uint256 _order, string _attackDetails);
    event PetLevlUp(uint256 _tokenId, uint256 _newLevel);
    
    constructor() ERC721("CryptoPets", "Pets"){
        // initialize the EX needed to upgrade the level
        // for 0-5 it's 100, 5-10 it is 200, and so on
        // the topest level is 60
        for(uint _level=0; _level<=60; _level++){
            requiredEX[_level] = (uint(_level) / uint(5) + 1) * 100;
        }
    }

    /**
     * mint one new NFT directly to a user
     * @param _player: to whom that the NFT would be mint
     * @return which index does the new NFT belong to, 0-5 for male/female penguines, 
     * charmander, charmeleon, squirtle and wartortle respectively
     */
    function addPet(address _player) public returns (uint256){

        require(createPetsAlready[_player] == false, "This user already has one pet");

        // mint one new NFT to _player if he does not own one
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(_player, newItemId);
        createPetsAlready[_player] = true;

        // set token URI, only image included here, six different images as following
        uint256 petRandom = randint(100, newItemId);
        uint256 petIndex;
        if(petRandom < 25){
            petIndex = 0;
        }else if(petRandom < 50){
            petIndex = 1;
        }else if(petRandom < 65){
            petIndex = 2;
        }else if(petRandom < 80){
            petIndex = 3;
        }else if(petRandom < 96){
            petIndex = 4;
        }else{
            petIndex = 5;
        }
        string memory petType = petOptions[petIndex];
        _setTokenURI(newItemId, petType);

        // set the initail HP, MP, EX and level
        HP[newItemId] = 80;
        MP[newItemId] = 9;
        EX[newItemId] = 0;
        level[newItemId] = 1;

        attackLow[newItemId] = 6;
        attackHigh[newItemId] = 12;

        emit PetsBirth(_player, petRandom, petIndex, petType);
        return petIndex;
    }

    function _petsFight(uint256 _tokenIdOne, uint256 _tokenIdTwo) public returns (uint256) {
        
    }

    function _petsFight(uint256 _tokenIdOne, uint256 _tokenIdTwo) public view returns (uint256 _winner, uint256 _order, string memory _attackDetails){
        // get initial HP of the two pets
        uint256 HP1 = HP[_tokenIdOne];
        uint256 HP2 = HP[_tokenIdTwo];
        // determine the order to attack
        _order = randint(2, HP1+HP2);
        _attackDetails = string(abi.encodePacked(Strings.toString(HP1), '-', abi.encodePacked(Strings.toString(HP2))));

        // initial seed to randomize the real attack value
        uint256 attackOne = HP1;
        uint256 attackTwo = HP2;

        do{
            // randomize harm for per attack
            attackOne = randint(attackHigh[_tokenIdOne]-attackLow[_tokenIdOne], attackOne * block.timestamp) + attackLow[_tokenIdOne];
            attackTwo = randint(attackHigh[_tokenIdTwo]-attackLow[_tokenIdTwo], attackTwo * block.difficulty) + attackLow[_tokenIdTwo];
            HP1 = nonNegativeSub(HP1, attackTwo);
            HP2 = nonNegativeSub(HP2, attackOne);

            // append the attack details to string variable
            _attackDetails = string(abi.encodePacked(_attackDetails, '-', Strings.toString(attackOne)));
            _attackDetails = string(abi.encodePacked(_attackDetails, '-', Strings.toString(attackTwo)));
            
        }while(HP1>0 && HP2>0);

        if(_order == 0){
            if(HP2 == 0){
                _winner = _tokenIdOne;
            }else{
                _winner = _tokenIdTwo;
            }
        }else{
            if(HP1 == 0){
                _winner = _tokenIdTwo;
            }else{
                _winner = _tokenIdOne;
            }
        }
        // emit PetsFight(_tokenIdOne, _tokenIdTwo, _winner, _order, _attackDetails);
    }

    /**
     * upgrade pets' level
     * @param _tokenId: which pet to upgrade
     */
    function levelUp(uint256 _tokenId) public{
        uint256 currentLevel = level[_tokenId];
        require(currentLevel <= 60, 'the pet has been upgraded to the topest level');
        require(EX[_tokenId] >= requiredEX[currentLevel], 'there is not enough EX to preceed the level upgrade');

        // deduct the EX and upgrade the level
        EX[_tokenId] = EX[_tokenId] - requiredEX[currentLevel];
        level[_tokenId] = level[_tokenId] + 1;
        emit PetLevlUp(_tokenId, currentLevel + 1);
    }

    /**
     * get random data from given range(Pseudo-Random)
     * @param _length: random selected from 0 -- _length, all intergers considered
     * @return randomed result
     */
    function randint(uint256 _length, uint256 _seed) public view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _seed)));
        return random%_length;
    }

    /**
     * max(x_1 - x_2, 0)
     * @param _value1: given Minute
     * @param _value2: given Minus
     * return the subtraction for these two integers, taken the maximum between real value and 0
     */
    function nonNegativeSub(uint256 _value1, uint256 _value2) public pure returns(uint256){
        if(_value1 > _value2){
            return (_value1 - _value2);
        }
        return 0;
    }

    /**
     * view total num of crypto pets
     * @return total num of cryptoPets
     */
    function viewTotalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    function viewRequiredEX(uint _level) external view returns (uint256) {
        return requiredEX[_level];
    }

    function viewLevel(uint _tokenId) external view returns (uint256){
        return level[_tokenId];
    }

}