pragma solidity ^0.5.16;

contract KYC {
    //admin variable to store the address of the admin
    address admin;

    enum BankActions {
        AddKYC,
        RemoveKYC,
        ApproveKYC,

        AddCustomer,
        RemoveCustomer,
        ModifyCustomer,
        DeleteCustomer,
        UpVoteCustomer,
        DownVoteCustomer,
        ViewCustomer,

        ReportSuspectedBank
    }
    
    struct Customer {
        string name;
        string data;
        uint256 upVotes;
        uint256 downVotes;
        address validatedBank;
        bool kycStatus;
    }

    struct Bank {
        string name;
        string regNumber;
        uint256 suspiciousVotes;
        uint256 kycCount;
        address ethAddress;
        bool isAllowedToAddCustomer;
        bool kycPrivilege;
        bool votingPrivilege;
    }

    struct Request {
        string customerName;
        string customerData;
        address bankAddress;
        bool isAllowed;
    }
    event ContractInitialized();
    event CustomerRequestAdded();
    event CustomerRequestRemoved();
    event CustomerRequestApproved();

    event NewCustomerCreated();
    event CustomerRemoved();
    event CustomerInfoModified();

    event NewBankCreated();
    event BankRemoved();
    event BankBlockedFromKYC();

    constructor() public {
        emit ContractInitialized();
        admin = msg.sender;
    }


    address[] bankAddresses;    //List of Bank Addresses.

    mapping(string => Customer) customersInfo;  
    mapping(address => Bank) banks; 
    mapping(string => Bank) bankVsRegNoMapping; 
    mapping(string => Request) kycRequests; 
    mapping(string => mapping(address => uint256)) upvotes; 
    mapping(string => mapping(address => uint256)) downvotes; 
    mapping(address => mapping(int => uint256)) bankActionsAudit;
     
    //To add a KYC request to the list. If kycPermission is set to false, the bank won’t be able to add requests for any customer.
    
    function addNewCustomerRequest(string memory custName, string memory custData) public payable returns(int){
        require(banks[msg.sender].kycPrivilege, "Requested Bank does not have KYC Privileges.");
        require(kycRequests[custName].bankAddress != address(0), "A KYC Request is already pending with this Customer.");

        kycRequests[custName] = Request(custName,custData, msg.sender, false);
        banks[msg.sender].kycCount++;

        emit CustomerRequestAdded();
        auditBankAction(msg.sender,BankActions.AddKYC);

        return 1;
    }

    //To remove a request from the list.
    
    function removeCustomerRequest(string memory custName) public payable returns(int){
        require(kycRequests[custName].bankAddress ==msg.sender, "Requested Bank is not authorized to remove this customer.");
        delete kycRequests[custName];
        emit CustomerRequestRemoved();
        auditBankAction(msg.sender,BankActions.RemoveKYC);
        return 1;
    }
     
    //To add a customer to the customer list. If IsAllowed is set to false, do nothing.
    
    function addCustomer(string memory custName,string memory custData) public payable {
        require(banks[msg.sender].isAllowedToAddCustomer, "Requested Bank does not have Voting Privileges.");
        require(customersInfo[custName].validatedBank == address(0), "Customer already exists.");

        customersInfo[custName] = Customer(custName, custData, 0,0,msg.sender,false);

        auditBankAction(msg.sender,BankActions.AddCustomer);

        emit NewCustomerCreated();
    }

    //To remove a customer from the customer list. KYC requests of that customer are also removed.
    
    function removeCustomer(string memory custName) public payable returns(int){
        require(customersInfo[custName].validatedBank != address(0), "Customer not found.");
        require(customersInfo[custName].validatedBank ==msg.sender, "Requested Bank is not authorized to remove this customer.");

        delete customersInfo[custName];
        removeCustomerRequest(custName);
        auditBankAction(msg.sender,BankActions.RemoveCustomer);
        emit CustomerRemoved();
        return 1;
    }
     
    //To modify data of a customer. Doing so will remove the customer from the KYC requests list and set the number of downvotes and upvotes to 0.
    
    function modifyCustomer(string memory custName,string memory custData) public payable returns(int){
        require(customersInfo[custName].validatedBank != address(0), "Customer not found");
        removeCustomerRequest(custName);

        customersInfo[custName].data = custData;
        customersInfo[custName].upVotes = 0;
        customersInfo[custName].downVotes = 0;

        auditBankAction(msg.sender,BankActions.ModifyCustomer);
        emit CustomerInfoModified();

        return 1;
    }
    
    //To view the details of a customer.
    
    function viewCustomerData(string memory custName) public payable returns(string memory,bool){
        require(customersInfo[custName].validatedBank != address(0), "Requested Customer not found");
        auditBankAction(msg.sender,BankActions.ViewCustomer);
        return (customersInfo[custName].data,customersInfo[custName].kycStatus);
    }
          
    //To retrieve KYC status of a customer. If True, then the KYC is complete for that customer.
    
    function getCustomerKycStatus(string memory custName) public payable returns(bool){
        require(customersInfo[custName].validatedBank != address(0), "Requested Customer not found");
        auditBankAction(msg.sender,BankActions.ViewCustomer);
        return (customersInfo[custName].kycStatus);
    }
     
    /*Allows Banks to cast upvotes for a customer. A vote from a bank is an acknowledgement that customer details have been accepted 
    and that the KYC process has been done by some bank for the customer.*/
    
    function upVoteCustomer(string memory custName) public payable returns(int){
        require(banks[msg.sender].votingPrivilege, "Requested Bank does not have Voting Privilege");
        require(customersInfo[custName].validatedBank != address(0), "Requested Customer not found");
        customersInfo[custName].upVotes++;
        customersInfo[custName].kycStatus = (customersInfo[custName].upVotes > customersInfo[custName].downVotes && customersInfo[custName].upVotes >  bankAddresses.length/3);
        upvotes[custName][msg.sender] = now;
        auditBankAction(msg.sender,BankActions.UpVoteCustomer);
        return 1;
    }
     
    //Allows Banks to cast a downvote for a customer. This means that the details submitted by the customer have not been accepted by the bank.
    function downVoteCustomer(string memory custName) public payable returns(int){
        require(banks[msg.sender].votingPrivilege, "Requested Bank does not have Voting Privilege");
        require(customersInfo[custName].validatedBank != address(0), "Requested Customer not found");
        customersInfo[custName].downVotes++;
        customersInfo[custName].kycStatus = (customersInfo[custName].upVotes > customersInfo[custName].downVotes && customersInfo[custName].upVotes >  bankAddresses.length/3);
        downvotes[custName][msg.sender] = now;
        auditBankAction(msg.sender,BankActions.DownVoteCustomer);
        return 1;
    }
     
    //Allows banks to report suspicion of another bank.
    function reportSuspectedBank(address suspiciousBankAddress) public payable returns(int){
        require(banks[suspiciousBankAddress].ethAddress != address(0), "Requested Bank not found");
        banks[suspiciousBankAddress].suspiciousVotes++;

        auditBankAction(msg.sender,BankActions.ReportSuspectedBank);
        return 1;
    }
     
    //To retrieve the report count of a bank.
    function getReportCountOfBank(address suspiciousBankAddress) public payable returns(uint256){
        require(banks[suspiciousBankAddress].ethAddress != address(0), "Requested Bank not found");
        return banks[suspiciousBankAddress].suspiciousVotes;
    }
     
    //To add banks to the smart contract. Can only be used by the admin.
    function addBank(string memory bankName,string memory regNumber,address ethAddress) public payable {

        require(msg.sender==admin, "Only admin can add bank");
        require(!areBothStringSame(banks[ethAddress].name,bankName), "A Bank already exists with same name");
        require(bankVsRegNoMapping[bankName].ethAddress != address(0), "A Bank already exists with same registration number");

        banks[ethAddress] = Bank(bankName,regNumber,0,0,ethAddress,true,true,true);
        bankAddresses.push(ethAddress);

        emit NewBankCreated();
    }
     
    //To remove a bank from the smart contract. Can only be used by the admin.
    function removeBank(address ethAddress) public payable returns(int){
        require(msg.sender==admin, "Only admin can remove bank");
        require(banks[ethAddress].ethAddress != address(0), "Bank not found");

        delete banks[ethAddress];

        emit BankRemoved();
        return 1;
    }
     
    //To deny permission to a bank from doing the KYC of a customer. Can only be used by the admin. 
    function blockBankFromKYC(address ethAddress) public payable returns(int){
        require(banks[ethAddress].ethAddress != address(0), "Bank not found");
        banks[ethAddress].kycPrivilege = false;
        emit BankBlockedFromKYC();
        return 1;
    }
     
    //To change the voting privileges of any bank. Can only be used by the admin.
    function blockBankFromVoting(address ethAddress) public payable returns(int){
        require(banks[ethAddress].ethAddress != address(0), "Bank not found");
        banks[ethAddress].votingPrivilege = false;
        emit BankBlockedFromKYC();
        return 1;
    }


    //Helper function that track actions of a bank and compare two strings respectively.
    function auditBankAction(address changesDoneBy, BankActions bankAction) private {
        bankActionsAudit[changesDoneBy][int(bankAction)] = now;
    }

    function areBothStringSame(string memory a, string memory b) private pure returns (bool) {
        if(bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(bytes(a)) == keccak256(bytes(b));
        }
    }
}
