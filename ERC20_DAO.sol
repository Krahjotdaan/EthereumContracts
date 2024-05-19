// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 indexed amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed amount);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address from, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DAO {
    struct Deposit {
        uint256 allTokens;
        uint256 frozenToken;
        uint256 unfrozenTime;
    }

    struct Proposal {
        uint256 pEndTime;
        uint256 pTokenYes;
        uint256 pTokenNo;
        address pCallAddress;
        bool pStatus;
        bytes pCallData;
    }

    IERC20 TOD;
    uint256 time;
    address owner;

    Proposal[] allProposals;

    mapping(uint256 => mapping(address => bool)) voters;
    mapping(address => Deposit) deposits;

    event AddProposal(uint256 pId, bytes pCallData, address pCallAddress);
    event FinishProposal(bool quorum, bool result, bool success);

    constructor(uint256 _time, address _TOD) {
        TOD = IERC20(_TOD);
        time = _time;
        owner = msg.sender;
    }

    /// @notice функция добавления депозита
    ///
    /// @dev вызывается функция transferFrom() на токене TOD
    /// @dev изменяется значение депозита для пользователя, вызвавшего функцию
    ///
    function addDeposit(uint256 _amount) external {
        require(TOD.transferFrom(msg.sender, address(this), _amount), "DAO: not enough tokens");
        deposits[msg.sender].allTokens += _amount;
    }

    /// @notice функция вывода депозита
    ///
    /// @param _amount - количество токенов, выводимых из депозита
    ///
    /// @dev нельзя вывести депозит, пока не закончены все голосования, в которых он участвует
    /// @dev нельзя вывести из депозита больше токенов, чем в нём есть
    /// @dev не забудьте изменить размер депозита пользователя
    ///
    function withdrawDeposit(uint256 _amount) external {
        Deposit storage deposit = deposits[msg.sender];
        if (deposit.frozenToken > 0 && deposit.unfrozenTime < block.timestamp) {
            deposit.frozenToken = 0;
            deposit.unfrozenTime = 0;
        }
        require(deposit.allTokens - deposit.frozenToken >= _amount, "DAO: not enough tokens");
        require(TOD.transfer((msg.sender), _amount));
        deposit.allTokens -= _amount;
    }

    /// @notice функция добавления нового голосования
    ///
    /// @param _pCallData - закодированные сигнатура функции и аргументы
    /// @param _pCallAddress - адрес вызываемого контракта
    ///
    /// @dev только owner может создавать новое голосование
    /// @dev добавляет новую структуру голосования Proposal в массив allProposals
    /// @dev не забудьте об ограничении по времени!
    /// @dev вызывает событие AddProposal
    ///
    function addProposal(bytes calldata _pCallData, address _pCallAddress) external {
        require(msg.sender == owner, "DAO: you are not an owner");
        allProposals.push(
            Proposal(
                block.timestamp + time,
                0,
                0,
                _pCallAddress,
                false,
                _pCallData
            )
        );
        emit AddProposal(allProposals.length - 1, _pCallData, _pCallAddress);
    }

    /// @notice Функция голосования
    ///
    /// @param _pId - id голосования
    /// @param _choice - голос за или против
    ///
    /// @dev вызывает прерывание если голосующий не внёс депозит
    /// @dev вызывает прерывание при попытке повторного голосования с одного адреса
    /// @dev вызывает прерывание если время голосования истекло
    ///
    /// @dev увеличиваем количество токенов за выбор голосующего
    /// @dev отмечаем адрес как проголосовавший
    /// @dev обновляем количество токенов, замороженных на депозите и время заморозки
    ///
    function vote(uint256 _pId, uint256 _tokens, bool _choice) external {
        Deposit memory deposit = deposits[msg.sender];
        Proposal memory proposal = allProposals[_pId];
        require(_tokens <= deposit.allTokens, "DAO: not enough tokens");
        require(!voters[_pId][msg.sender], "DAO: you have already voted");
        require(block.timestamp < proposal.pEndTime, "DAO: proposal time is over");

        voters[_pId][msg.sender] = true;

        if (_choice) {
            allProposals[_pId].pTokenYes += _tokens;
        } 
        else {
            allProposals[_pId].pTokenNo += _tokens;
        }

        deposits[msg.sender].frozenToken = _tokens;

        if (proposal.pEndTime > deposit.unfrozenTime) {
            deposits[msg.sender].unfrozenTime = proposal.pEndTime;
        }
    }

    /// @notice Функция окончания голосования
    ///
    /// @param _pId - id голосования
    ///
    /// @dev вызывает прерывание если время голосования не истекло
    /// @dev вызывает прерывание если голосование уже было завершено ранее
    ///
    /// @dev выставляет статус, что голосование завершено
    /// @dev проверяет, что набрался кворум
    /// @dev если набрался кворум количество токенов ЗА больше, количество токнов ПРОТИВ, вызывается функция
    /// @dev вызывает событие FinishProposal
    ///
    function finishProposal(uint256 _pId) external {
        Proposal memory proposal = allProposals[_pId];
        require(block.timestamp > proposal.pEndTime, "DAO: proposal is still going on");
        require(!proposal.pStatus, "DAO: proposal is already completed");

        allProposals[_pId].pStatus = true;

        bool quorum = proposal.pTokenYes + proposal.pTokenNo > TOD.totalSupply() / 2;
        bool result = proposal.pTokenYes > proposal.pTokenNo;
        bool success = false;

        if (quorum && result) {
            (success, ) = proposal.pCallAddress.call(proposal.pCallData);
            require(success);
        }

        emit FinishProposal(quorum, result, success);
    }

    /// @notice функция для получения информации о депозите
    ///
    /// @return возвращает структуру deposit с информацией о депозите пользователя, вызвавшего функцию
    ///
    function getDeposit() external view returns (Deposit memory) {
        return deposits[msg.sender];
    }

    /// @notice Функция для получения списка всех голосований
    ///
    /// @dev возвращает массив allProposals со всеми голосованиями
    ///
    function getAllProposal() external view returns (Proposal[] memory) {
        return allProposals;
    }

    /// @notice Функция для получения информации об одном голосовании по его id
    ///
    /// @param _pId - id голосования
    ///
    /// @dev вызывает прерывание, если такого id не существует
    ///
    /// @return возвращает одно голосование - структуру Proposal
    ///
    function getProposalByID(uint256 _pId) external view returns (Proposal memory) {
        return allProposals[_pId];
    }
}
