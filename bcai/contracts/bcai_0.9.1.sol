//version 0.9.1
//Author: Taurus, Landry
//Copyright: tlu4@lsu.edu

//NOTE: non-view functions cannot return values, only possible way is event

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;   //return self-defined type

contract TaskContract {
    //list
    mapping (uint256 => Provider) public providerList;  //history
    mapping (uint256 => Request) public requestList;    //history
    
    //mapping address with ID
    mapping (address => uint256[])  public providerMap;
    mapping (address => uint256[])  public requestMap;
 
    mapping (uint256 => uint256) public balanceList;    //reqID => balance
    //ID - counter
    uint256 private providerCount;     //+1 each time
    uint256 private requestCount;
    //Pool
    uint256[] providerPool;
    uint256[] pendingPool;
    uint256[] providingPool;
    uint256[] validatingPool;
    

    constructor() public {      //sol 5.0 syntax
        delete providerPool;
        delete pendingPool;
        delete providingPool;
        delete validatingPool;
        providerCount = 0;
        requestCount = 0;
    }

    struct Request {
        uint256 reqID;              //requestID is the only identifier for each Request
        uint256 blockNumber;
        address payable addr;       //payable is new feature from sol v5.0
        //uint256 assignedProvider;
        address payable provider;         //
        //address payable provider;   //addr of worker
        uint64  time;               //time
        uint16  target;             //target 0-100.00
        uint256 price;              //the max amount he can pay
        uint64  dataID;             //dataID used to fetch the off-chain data
        uint64  resultID;           //dataID to fetch the result
        uint64  numValidationsNeeded;   //user defined the validation
        bool[]  validations;        //multisignature from validations
        bool    isValid;            //the final flag
        byte    status;              //0: 'pending', 1:'providing', 2: validating, 3: complete
    }

    struct Provider {
        uint256 provID;
        uint256 blockNumber;
        address payable addr;       //providers address

        
                                    //TODO: the provider name registration.
        uint64  maxTime;            //max time
        uint16  maxTarget;          //max target he need
        uint256 minPrice;           //lowest price can accept
        bool    available;          // Used to determine if provider is already doing something
    }

    event ProviderAdded     (uint256 provID, address payable addr);
    event ProviderStopped   (uint256 provID, address payable addr);
    event ProviderUpdated   (uint256 provID, address payable addr);
    event TaskAssigned          (uint256 reqID, uint256 provID);     // next step: call completeTask
    //event ValidationRequested   (address validator, uint128 reqID);    // next step: validator calls submitValidation
    //event TaskCompleted         (address requestor, uint128 reqID);    // done


    
    // Function called to become a provider. New on List, Map and Pool. 
    // NOTE: cannot use to update. You must stop a previous one and start a new one.
    // TIPS: gas cost: don't create local copy and write back, modify the storage directly.
    function startProviding(uint64 maxTime, uint16 maxTarget, uint64 minPrice) public returns (byte) {
        // register a new provider object in the List and map              
        providerList[providerCount].provID         = providerCount;
        providerList[providerCount].blockNumber    = block.number;
        providerList[providerCount].addr           = msg.sender;             
        providerList[providerCount].maxTime        = maxTime;       
        providerList[providerCount].maxTarget      = maxTarget;
        providerList[providerCount].minPrice       = minPrice;
        
        // add to map
        providerMap[msg.sender].push(providerCount);
        // put it into the pool
        providerPool.push(providerCount);
        providerList[providerCount].available      = true;  //turn on the flag at LAST
        // ready for the next       
        emit ProviderAdded(providerCount, msg.sender);
        providerCount++;
        
    }
    
    // Send a request from user to blockchain.
    // Assumes price is including the cost for verification
    function requestTask(uint64 dataID, uint16 target, uint64 time) payable public returns (byte) {
        //register on List
        requestList[requestCount].reqID         = requestCount;
        requestList[requestCount].blockNumber   = block.number;  
        requestList[requestCount].addr          = msg.sender;
        requestList[requestCount].provider      = address(0);      
        requestList[requestCount].time          = time;    
        requestList[requestCount].target        = target;
        requestList[requestCount].price         = msg.value;
        requestList[requestCount].dataID        = dataID;
        //requestList[requestCount].resultID  = 0;
        requestList[requestCount].numValidationsNeeded = 1;
        //requestList[requestCount].validations = emptyArray;
        //requestList[requestCount].isValid   = false;
        
        //add new to map
        requestMap[msg.sender].push(requestCount);
        
        //add new to requestPool
        pendingPool.push(requestCount);
        requestList[requestCount].status = '0' ;     //pending 0x30, not 0
        //update requestID
        
        //update count
        requestCount++;     //count already stands for the # of req now.
        return '0';
        //assignTask(requestCount -1);
    }
    
    
    // Stop a provider, if you know a provider ID. Get em using getProvID()
    // Must be sent from the provider address or it will be failed.
    function stopProviding(uint256 provID) public returns (bool) {
        // If the sender is currently an active provider
        bool flag = false;
        if (providerList[provID].available == true                 //can only stop available provider
                && providerList[provID].addr == msg.sender) {      //you cannot delete other's provider            
            delete providerList[provID];                           //delete from List
            flag = ArrayPop(providerMap[msg.sender], provID);      //delete form Map
            flag = ArrayPop(providerPool, provID) && flag;         //delete from Pool             
        }
        if(flag) emit ProviderStopped(provID, msg.sender);
        return flag;
    }

    function updateProvider(uint64 maxTime, uint16 maxTarget, uint64 minPrice, uint256 provID) public returns (bool) {      
        bool flag = false;
        if(providerList[provID].available == true           //can only modify available provider
        && providerList[provID].addr != msg.sender){        //you are modify other's config
            providerList[provID].blockNumber    = block.number;         
            providerList[provID].maxTime        = maxTime;       
            providerList[provID].maxTarget      = maxTarget;
            providerList[provID].minPrice       = minPrice;
            //update pool       -- pop then push , because we need to scan pool anyway
            flag = ArrayPop(providerPool,provID);           // pop first                                      
            providerPool.push(provID);                      // push in both case anyway
            //update map -- no need provID not changed.
            emit ProviderUpdated(provID, msg.sender);
            return flag;
        }
    }
/*
    // Used to be sure you are seen as available. e.g. power outage caused you to lose available status on network.
    // Not to be called after stopProviding to resume -- startProviding used in this case.
    //function restart() public returns (bool) {
    //if (providerList[providerID[msg.sender]].addr == msg.sender) {
    //     providers[providerID[msg.sender]].available = true;
    //       return true;
    //    }
    //else {
    //    return false; // provider wasnt found in mapping
    //  }
    //}


    // Search in the requestPool, find a job for current provider. Triggered by startProviding
    // Return true if a match or false if not.
    // Returns: 0: successfully assigned
    //          1: searched all providers but find no match
    //          2: no available provider right now
    //          3: failure during poping pool
    function assignProvider(address payable addr) private returns (byte){
        if(requestPool.length == 0) return '2';
        else {
            //search throught the requestPool
            for (uint128 i = 0; i < requestPool.length; i++){
                //save the re-usable reqID , may save gas
                uint128 reqID = requestPool[i]; //     
                if( requestList[reqID].time     < providerList[addr].maxTime &&
                    requestList[reqID].target   < providerList[addr].maxTarget &&
                    requestList[reqID].price    > providerList[addr].minPrice){
                        //meet the requirement, assign the task
                        //update provider
                        providerList[addr].available = false;
                        bool isPopped = providerPop(addr);
                        if(!isPopped) return '3';

                        //update request
                        requestList[reqID].provider = addr;
                        requestList[reqID].status = '1';    //providing
                        isPopped = requestPop(reqID);
                        if(!isPopped) return '3';

                        //update balanceList            addr here is requester's
                        balanceList[requestList[reqID].addr] += requestList[reqID].price; 
                                               
                        //status move from pending to providing
                        pendingCount--;
                        providingCount++;
                        emit TaskAssigned(addr, providerID[addr], reqID);
                        return '0';                   
                }                
            }
            //after for loop and no match
            return '1';
        }
    }



*/

    

    /*function requestTask(uint64 dataID, uint16 target, uint64 time) payable public returns (bool) {
        bool[] memory emptyArray;
        Request memory req = Request(           //create a temp memory var
            msg.sender,             //addr
            address(0),             //provider
            requestCount,           //reqID
            dataID,                 //dataID
            time,                   //time    
            target,                 //target   0-100
            msg.value,              //price 
            0,                      //resultID
            1,                      //numValidationsNeeded
            emptyArray,             //sig list
            false,                  //isValid
            0                       //status  0-3 0: pending
        );

        //copy the mem var into storage
        requestList[requestCount] = req;        //requestCount used as index here, from 0 to +++
        //add new to requestPool
        requestPool.push(requestCount);
        //update requestID
        requestID[msg.sender].push(requestCount);
        //update count
        requestCount++;     //count already stands for the # of req now.
        pendingCount++;
        return assignTask();
    }


    // Assigning one task to one of the available providers. Only called from requestTask (private)
    // Search in the providerPool, if no match in the end, return false
    //could only assign one task at a time
    //auto sel the first searching result for now, no comparation between multiple availability.
    //TODO: need ot add preference next patch
    // Returns: 0: successfully assigned
    //          1: searched all providers but find no match
    //          2: no available provider right now
    //          3: failure during poping pool
    function assignTask(uint128 reqID) private returns (byte) {
        //provider availability is checked in pool not in list
        if (providerPool.length == 0)   return '2';
        else {            //if any provider in pool
            for (uint64 i = 0; i < providerPool.length; i++) {
                // save the provider's addr, reusable and save gas cost
                address payable addr  = providerPool[i];
                if(addr != address(0) && providerList[addr].available == true){
                    // Check if request conditions meet the providers requirements
                    if (requestList[reqID].target <= providerList[addr].maxTarget && 
                        requestList[reqID].time <= providerList[addr].maxTime && 
                        requestList[reqID].price >= providerList[addr].minPrice) {
                        
                        //update provider:
                        providerList[addr].available = false;
                        bool isPopped = providerPop(addr);
                        if(!isPopped) return '3';

                        //update request
                        requestList[reqID].provider = addr;
                        requestList[reqID].status = '1';    //providing
                        isPopped = requestPop(reqID);
                        if(!isPopped) return '3';

                        //update balanceList              
                        balanceList[requestList[reqID].addr] += requestList[reqID].price; 
                                               
                        //status move from pending to providing
                        pendingCount--;
                        providingCount++;
                        //NOTE: assign existing task should not increase the # of requestCount

                        //EVENT
                        emit TaskAssigned(addr, providerID[addr], reqID); // Let provider listen for this event to see he was selected
                        return '0';
                    }
                }
            }
            // No provider was found matching the criteria -- request failed
            requestList[reqID].addr.transfer(requestList[reqID].price); // Returns the ether to the sender
            return '1';
        }
    }



/*

    // Provider will call this when they are done and the data is available.
    // This will invoke the validation stage
    function completeTask(uint128 reqID, uint64 resultID) public returns (bool) {
        // Confirm msg.sender is actually the provider of the task he claims
        if (msg.sender == requestList[reqID].provider) {
            requestList[reqID].isCompleted = true;
            requestList[reqID].resultID = resultID;
            providerList[providerID[msg.sender]].available = true;
            return validateTask(reqID);
        }
        else {
            return false;
        }
    }
/*
    // Called by completeTask before finalizing stuff. Contract checks with validators
    // Returns false if there wasnt enough free providers to send out the required number of validation requests
    function validateTask(uint128 reqID) private returns (bool) {
        uint64 numValidators = 3; // need validation from 1/10 of nodes -- could change
        //uint numValidators = providerCount / 10; 
        uint validatorsFound = 0;
        requestList[reqID].numValidationsNeeded = numValidators;
        for (uint64 i=0; i<providerCount + spaces.length && validatorsFound<numValidators; i++) {
            if (providerList[i].addr == address(0)) {
                continue;
            }
            if (providerList[i].available) {
                // EVENT: informs validator that they were selected and need to validate
                emit ValidationRequested(providerList[i].addr, reqID);
                validatorsFound++;
            }
        }
        if (validatorsFound == numValidators) {
            return true;
        }
        return false;
    }





    // needs to be more secure by ensuring the submission is coming from someone legit 
    function submitValidation(uint128 reqID, bool result) public returns (bool) {
        // Pay the validator 
        uint partialPayment = requestList[reqID].price / 100; // amount each validator is paid
        msg.sender.transfer(partialPayment);
        balanceList[requestList[reqID].addr] -= partialPayment;
        // Put the result in the request struct
        requestList[reqID].validations.push(result);
        // If enough validations have been submitted
        if (requestList[reqID].validations.length == requestList[reqID].numValidationsNeeded) {
            return checkValidation(reqID, requestList[reqID].price - requestList[reqID].numValidationsNeeded * partialPayment);
        }
    }
    
    function checkValidation(uint128 reqID, uint payment) private returns (bool) {
        // Add up successful validations
        uint64 successCount = 0;
        for (uint64 i=0; i<requestList[reqID].validations.length; i++) {
            if (requestList[reqID].validations[i]) successCount++;
        }
        // if 2/3 of validation attempts were successful
        if (successCount  >= requestList[reqID].numValidationsNeeded * 2 / 3  ) { 
            // if 2/3 of validations were valid then provider gets remainder of money
            requestList[reqID].provider.transfer(payment); 
            balanceList[requestList[reqID].addr] -= payment;
            requestList[reqID].isValid = true; // Task was successfully completed! 
        }
        // otherwise, work was invalid, the providers payment goes back to requester
        else {
            requestList[reqID].addr.transfer(payment);
            balanceList[requestList[reqID].addr] -= payment;
        }
        // EVENT: task is done whether successful or not
        emit TaskCompleted(requestList[reqID].addr, reqID);
        return requestList[reqID].isValid;
    }
*/
/////////////////////////////////////////////////////////////////////
 // Used to dynamically remove elements from array of open provider spaces. 
    // Using a swap and delete method, search for the desired addr throughout the whole array
    // delete the desired and swap the whole with last element
    /*function AddrArrayPop(address payable [] storage addrArray, uint256 target) private returns(bool) {
        for(uint64 i = 0; i < addrArray.length; i++){
            if (addrArray[i] == target) {
                //swap last element with hole
                addrArray[i] = addrArray[addrArray.length-1];
                //delete last item
                delete addrArray[addrArray.length-1];
                 //decrease size
                addrArray.length--;
                return true;
            }
        }
        return false; //fail to search: no matching in pool
    }*/

    function ArrayPop(uint256[] storage array, uint256 target) private returns (bool) {
        for(uint64 i = 0; i < array.length; i++){
            if (array[i] == target) {
                //swap last element with hole
                array[i] = array[array.length-1];
                //delete last item
                delete array[array.length-1];
                //decrease size
                array.length--;
                return true;
            }
        }
        return false;   //fail to search: no matching in pool
    } 
    function getMyProvID() public view returns (uint256[] memory){
        return providerMap[msg.sender];
    }
    function getMyReqID() public view returns (uint256[] memory){
        return requestMap[msg.sender];
    }
    function getProviderID(address addr) public view returns (uint256[] memory){
        return providerMap[addr];
    }
    function getRequestID(address addr) public view returns (uint256[] memory){
        return requestMap[addr];
    }

    /////////////////////////////////////////////////////////////////////////////////
    //some helpers defined here
    /*function testTask() public {
        emit TaskAssigned(msg.sender, 11, 22);
    }*/
    function getProvider(uint256 ID) public view returns(Provider memory){
        return providerList[ID];
    }
    function getRequest(uint256 ID) public view returns (Request memory){
	    return requestList[ID];
    }
    function getProviderCount() public view returns (uint256){
        return providerCount;
    }
    function getRequestCount() public view returns (uint256){
        return requestCount;
    }
    function getProviderPool() public view returns (uint256[] memory){
        return providerPool;
    }
    function getRequestPool() public view returns (uint256[] memory){
        return pendingPool;
    }
    function getProviderPoolSize() public view returns (uint256){
        return providerPool.length;
    }
    function getRequestPoolSize() public view returns (uint256){
        return pendingPool.length;
    }
    //function getBalance(address addr) public view returns (uint256){
    //    return balanceList[addr];
    //}
    function listRequests(uint256[] memory IDList) public view returns(Request[50] memory){
	    Request[50] memory allRequest;
	    for (uint64 i = 0; i < IDList.length; i++){
		    allRequest[i] = getRequest(IDList[i]);
	    }
	    return allRequest;
    }
    function listProviders(uint256[] memory IDList) public view returns(Provider[50] memory){
        Provider[50] memory allProvider;
        //address addr;
        for (uint64 i = 0; i < IDList.length;i++){
            allProvider[i] = getProvider(IDList[i]);
        }
        return allProvider;
    }
    function listAllRequests() public view returns(Request[50] memory){
	    Request[50] memory allRequest;
	    for (uint64 i = 0; i < requestCount; i++){
		    allRequest[i] = getRequest(i);
	    }
	    return allRequest;
    }
    function listAllProviders() public view returns(Provider[50] memory){
	    Provider[50] memory allProvider;
	    for (uint64 i = 0; i < providerCount; i++){
		    allProvider[i] = getProvider(i);
	    }
	    return allProvider;
    }
    function listProviders() public view returns(Provider[50] memory){
        Provider[50] memory allProvider;
        //address addr;
        for (uint64 i = 0; i < providerCount;i++){
            /*if(providerPool.length > 0) {
                addr = providerPool[i];     
            }else {
                addr = address(0);
            }*/
            allProvider[i] = getProvider(i);
        }
        return allProvider;
    }
    /*function listTestProviders() public view returns(Provider[3] memory){
        Provider[3] memory allProvider;
        for (uint64 i = 0; i < 3;i++){
            allProvider[i] = getTestProvider(i);
        }
        return allProvider;
    }*/

}