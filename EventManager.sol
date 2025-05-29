// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract EventManager {
    struct Attendee {
        string email;
        bool hasAttended;
    }


    struct Event {
        address creator;
        mapping(string => Attendee) attendees;
        string[] attendeeEmails;
        bool exists;
    }

    mapping(string => Event) private events;
    string[] private eventIds;

    // Track deposits of tokens for each event
    mapping(string => mapping(address => uint256)) public eventDeposits;

    event EventCreated(string indexed eventId, address indexed creator);
    event AttendanceMarked(string indexed eventId, string attendeeEmail, bool hasAttended);
    event DepositMade(string indexed eventId, address indexed depositor, address indexed token, uint256 amount);
    event Payout(string indexed eventId, address indexed recipient, address indexed token, uint256 amount);

    // Create a new event
    function createEvent(string memory _eventId) public {
        require(!events[_eventId].exists, "Event ID already in use");

        Event storage newEvent = events[_eventId];
        newEvent.creator = msg.sender;
        newEvent.exists = true;
        eventIds.push(_eventId);

        emit EventCreated(_eventId, msg.sender);
    }

    // Mark attendance
    function markAttendance(string memory _eventId, string memory _attendeeEmail, bool _status) public {
        require(events[_eventId].exists, "Event does not exist");
        require(msg.sender == events[_eventId].creator, "Only the creator can mark attendance");

        if (bytes(events[_eventId].attendees[_attendeeEmail].email).length == 0) {
            events[_eventId].attendees[_attendeeEmail] = Attendee({
                email: _attendeeEmail,
                hasAttended: _status
            });
            events[_eventId].attendeeEmails.push(_attendeeEmail);
        } else {
            events[_eventId].attendees[_attendeeEmail].hasAttended = _status;
        }

        emit AttendanceMarked(_eventId, _attendeeEmail, _status);
    }

    // Deposit ERC20 tokens for an event
   function depositAmount(string memory _eventId, uint256 _amount, address _token) public {
    require(events[_eventId].exists, "Event does not exist");
    require(_amount > 0, "Amount must be > 0");

    IERC20 token = IERC20(_token);

    uint256 senderBalance = token.balanceOf(msg.sender);
    require(senderBalance >= _amount, "Insufficient balance");

    bool success = token.transferFrom(msg.sender, address(this), _amount);
    require(success, "Token transfer failed");

    eventDeposits[_eventId][_token] += _amount;

    emit DepositMade(_eventId, msg.sender, _token, _amount);
}

    // Payout: send balance of tokens for an event to creator
    function payout(string memory _eventId, address _token) public {
        require(events[_eventId].exists, "Event does not exist");
        require(msg.sender == events[_eventId].creator, "Only creator can payout");

        uint256 amount = eventDeposits[_eventId][_token];
        require(amount > 0, "No balance to payout");

        eventDeposits[_eventId][_token] = 0; // Reset balance first

        IERC20 token = IERC20(_token);
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        emit Payout(_eventId, msg.sender, _token, amount);
    }

    // Get all event IDs
    function getAllEventIds() public view returns (string[] memory) {
        return eventIds;
    }

    // Get event creator
    function getEventCreator(string memory _eventId) public view returns (address) {
        require(events[_eventId].exists, "Event does not exist");
        return events[_eventId].creator;
    }

    // Check if an event exists
    function eventExists(string memory _eventId) public view returns (bool) {
        return events[_eventId].exists;
    }

    // Get list of attendee emails for an event
    function getAttendeeEmails(string memory _eventId) public view returns (string[] memory) {
        require(events[_eventId].exists, "Event does not exist");
        return events[_eventId].attendeeEmails;
    }

    // Get details of a specific attendee by email
    function getAttendee(string memory _eventId, string memory _attendeeEmail) public view returns (string memory, bool) {
        require(events[_eventId].exists, "Event does not exist");
        Attendee storage a = events[_eventId].attendees[_attendeeEmail];
        require(bytes(a.email).length != 0, "Attendee not found");
        return (a.email, a.hasAttended);
    }

    // Get event deposits for a specific token
    function getEventTokenBalance(string memory _eventId, address _token) public view returns (uint256) {
        require(events[_eventId].exists, "Event does not exist");
        return eventDeposits[_eventId][_token];
    }

    // Get overall balance of the contract for a token
    function getContractTokenBalance(address _token) public view returns (uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }

    // Get complete event data including attendees
    function getEventDetails(string memory _eventId) public view returns (
        address creator,
        string[] memory emails,
        bool[] memory hasAttendedList
    ) {
        require(events[_eventId].exists, "Event does not exist");

        Event storage e = events[_eventId];
        uint256 count = e.attendeeEmails.length;
        bool[] memory attendedList = new bool[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory email = e.attendeeEmails[i];
            attendedList[i] = e.attendees[email].hasAttended;
        }

        return (e.creator, e.attendeeEmails, attendedList);
    }

    function batchMarkAttendance(
    string memory _eventId,
    string[] memory _attendeeEmails,
    bool[] memory _statuses
) public {
    require(events[_eventId].exists, "Event does not exist");
    require(msg.sender == events[_eventId].creator, "Only the creator can mark attendance");
    require(_attendeeEmails.length == _statuses.length, "Emails and statuses length mismatch");

    Event storage e = events[_eventId];

    for (uint256 i = 0; i < _attendeeEmails.length; i++) {
        string memory email = _attendeeEmails[i];
        bool status = _statuses[i];

        if (bytes(e.attendees[email].email).length == 0) {
            e.attendees[email] = Attendee({
                email: email,
                hasAttended: status
            });
            e.attendeeEmails.push(email);
        } else {
            e.attendees[email].hasAttended = status;
        }

        emit AttendanceMarked(_eventId, email, status);
    }
}

}
