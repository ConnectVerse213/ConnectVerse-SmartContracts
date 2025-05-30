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
        uint256 depositedAmount;
        address depositedToken;
    }

    struct Event {
        address creator;
        mapping(string => Attendee) attendees;
        string[] attendeeEmails;
        bool exists;
    }

    mapping(string => Event) private events;
    string[] private eventIds;

    event EventCreated(string indexed eventId, address indexed creator);
    event AttendanceMarked(string indexed eventId, string attendeeEmail, bool hasAttended);
    event DepositMade(string indexed eventId, address indexed depositor, address indexed token, uint256 amount, string email);
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

        Attendee storage attendee = events[_eventId].attendees[_attendeeEmail];
        require(bytes(attendee.email).length != 0, "Attendee has not deposited");

        attendee.hasAttended = _status;

        emit AttendanceMarked(_eventId, _attendeeEmail, _status);
    }

    // Batch mark attendance
    function batchMarkAttendance(
        string memory _eventId,
        string[] memory _attendeeEmails,
        bool[] memory _statuses
    ) public {
        require(events[_eventId].exists, "Event does not exist");
        require(msg.sender == events[_eventId].creator, "Only the creator can mark attendance");
        require(_attendeeEmails.length == _statuses.length, "Emails and statuses length mismatch");

        for (uint256 i = 0; i < _attendeeEmails.length; i++) {
            markAttendance(_eventId, _attendeeEmails[i], _statuses[i]);
        }
    }

    // Deposit ERC20 tokens for an event along with email
    function depositAmount(string memory _eventId, uint256 _amount, address _token, string memory _email) public {
        require(events[_eventId].exists, "Event does not exist");
        require(_amount > 0, "Amount must be > 0");
        require(bytes(_email).length != 0, "Email must not be empty");

        IERC20 token = IERC20(_token);

        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        Attendee storage attendee = events[_eventId].attendees[_email];
        if (bytes(attendee.email).length == 0) {
            // New attendee
            attendee.email = _email;
            events[_eventId].attendeeEmails.push(_email);
        }

        // Accumulate deposit for the attendee
        attendee.depositedAmount += _amount;
        attendee.depositedToken = _token;

        emit DepositMade(_eventId, msg.sender, _token, _amount, _email);
    }

    // Payout: only pay out amounts of attendees who attended
    function payout(string memory _eventId, address _token) public {
        require(events[_eventId].exists, "Event does not exist");
        require(msg.sender == events[_eventId].creator, "Only creator can payout");

        Event storage e = events[_eventId];
        uint256 totalPayout = 0;

        for (uint256 i = 0; i < e.attendeeEmails.length; i++) {
            string memory email = e.attendeeEmails[i];
            Attendee storage attendee = e.attendees[email];

            if (attendee.hasAttended && attendee.depositedToken == _token && attendee.depositedAmount > 0) {
                totalPayout += attendee.depositedAmount;

                // Reset the deposit to zero after payout
                attendee.depositedAmount = 0;
            }
        }

        require(totalPayout > 0, "No eligible deposits to payout");

        IERC20 token = IERC20(_token);
        bool success = token.transfer(msg.sender, totalPayout);
        require(success, "Token transfer failed");

        emit Payout(_eventId, msg.sender, _token, totalPayout);
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
    function getAttendee(string memory _eventId, string memory _attendeeEmail) public view returns (
        string memory email,
        bool hasAttended,
        uint256 depositedAmount,
        address depositedToken
    ) {
        require(events[_eventId].exists, "Event does not exist");
        Attendee storage a = events[_eventId].attendees[_attendeeEmail];
        require(bytes(a.email).length != 0, "Attendee not found");
        return (a.email, a.hasAttended, a.depositedAmount, a.depositedToken);
    }

    // Get contract's overall balance for a token
    function getContractTokenBalance(address _token) public view returns (uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }

    // Get event details including attendees and their status
    function getEventDetails(string memory _eventId) public view returns (
        address creator,
        string[] memory emails,
        bool[] memory hasAttendedList,
        uint256[] memory depositedAmounts,
        address[] memory depositedTokens
    ) {
        require(events[_eventId].exists, "Event does not exist");

        Event storage e = events[_eventId];
        uint256 count = e.attendeeEmails.length;

        bool[] memory attendedList = new bool[](count);
        uint256[] memory amounts = new uint256[](count);
        address[] memory tokens = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory email = e.attendeeEmails[i];
            attendedList[i] = e.attendees[email].hasAttended;
            amounts[i] = e.attendees[email].depositedAmount;
            tokens[i] = e.attendees[email].depositedToken;
        }

        return (e.creator, e.attendeeEmails, attendedList, amounts, tokens);
    }
}

