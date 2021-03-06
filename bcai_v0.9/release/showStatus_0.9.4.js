////////////////////////////////////////////////////////////////
//user's js script
//version: 0.9.4
//author: taurus tlu4@lsu.edu
//use: $ node user.js --help
/////////////////////////////////////////////////////////////////
var version = "bcai_client v0.9.4     ----  by Taurus"
//get arguments from console
var argv = require('minimist')(process.argv.slice(2));
//argument example:
//node worker.js -u 2 -b 3
//{ _: [], u: 2, b: 3 }
//console.log(argv['u'])
if(argv['help']) {
    //console.log("Arguments: -a # : accounts[#]");
    console.log(" --acc   : list all accounts address / -a list");
	console.log(" --debug : show all debug details, including object details");
	console.log(" --list  : list minimum object Request and Provider");
	console.log(" --all   : most powerful history tracing option / use with caution");
    //console.log(" --stop :  stop the current provider")
	process.exit();
}
if(argv['v'] || argv['version']){
    console.log(version);
    process.exit();
}
////////////////////////////////////////////
var Web3, web3, MyContract, myContract;
var myAccounts;

function init() {
	Web3 = require('web3');
	web3 = new Web3('ws://localhost:8545');
	MyContract = require('../build/contracts/TaskContract.json');
	myContract = new web3.eth.Contract(MyContract.abi, MyContract.networks[512].address);
}

///////////////////////////////////////////////main
init();
web3.eth.getAccounts()
.then(function(myAccounts){		//resolve
	showCurrentStatus(myAccounts);
	}
, function(err){				//reject
	console.log("Error, ",err);
})	
.then(function(){
	//  event moniotring [important]
	myContract.events.SystemInfo({
		fromBLock: 0,
		toBlock: 'latest'
	}, function(err, event){
		if(err) console.log(err);
	}).on('data', function(event){
		PrintEvent(event);
	})
	
	myContract.events.UpdateInfo({
		fromBLock: 0,
		toBlock: 'latest'
	}, function(err, event){
		if(err) console.log(err);
	}).on('data', function(event){
		PrintEvent(event);		
	})

	myContract.events.PairingInfo({
		fromBLock: 0,
		toBlock: 'latest'
	}, function(err, event){
		if(err) console.log(err);
	}).on('data', function(event){
		PrintEvent(event);
	})

	//display current status every new block
	web3.eth.subscribe('newBlockHeaders', function(err, result){
		if(err) console.log("ERRRR", err, result);
		showCurrentStatus();
   })
})
////////////////////////////////////////////////
function showCurrentStatus(myAccounts){
	if (myAccounts != undefined)
		console.log(myAccounts);			//print accounts List //when updating , will be undefined
	if (argv['acc'] || argv['a'] != undefined){
        process.exit();
    }	
	//get # of providers and print
	//showProviders();
	//get # of request and print
	//showRequests();
	return showStatics().then(function(){
	 	showPools();
	})
}
function showStatics(){		//called yb showCurrentStatus
	return myContract.methods.getRequestCount().call().then(function(totalCount){
		console.log("=======================================================   <- updated!");
		console.log("Total Request since start: ", totalCount);
	}).then(function(){
		return myContract.methods.getProviderCount().call().then(function(totalCount){
			console.log("Total provider since start: ", totalCount);
		})
	})
}
function showPools(){		//optional [--list] 
	//NOTE: the following 'return' is important, it actually return the promise object
	//this avoid the issue of unhandled promise.
	return myContract.methods.getProviderPool().call().then(function(provPool){
		console.log("=======================================================");
		console.log("Active provider pool: Total = ", provPool.length);
		console.log(provPool);
		return provPool;
	}).then(function(provPool){
		if(argv['list'] && provPool.length >0) return ListoutPool(provPool,'provider');
	}).then(function(){
		return myContract.methods.getRequestPool().call().then(function(reqPool){
			console.log("=======================================================")
			console.log("Pending pool:  Total = ", reqPool.length);
			console.log(reqPool);
			return reqPool;
		})
	}).then(function(reqPool){
		if(argv['list'] && reqPool.length>0) return ListoutPool(reqPool, 'request');
	}).then(function(){
		return myContract.methods.getProvidingPool().call().then(function(providingPool){
			console.log("=======================================================")
			console.log("Providing pool:  Total = ", providingPool.length);
			console.log(providingPool);
			return providingPool;
		})
	}).then(function(providingPool){
		if(argv['list'] && providingPool.length>0) return ListoutPool(providingPool, 'request');
	}).then(function(){
		return myContract.methods.getValidatingPool().call().then(function(valiPool){
			console.log("=======================================================")
			console.log("Validating pool:  Total = ", valiPool.length);
			console.log(valiPool);
			return valiPool;
			})
	}).then(function(valiPool){
		if(argv['list'] && valiPool.length>0) return ListoutPool(valiPoolPool, 'request');
	})
	
}
//[developed] [tested]
function ListAllProvidersInHistory(){
	return myContract.methods.getProviderCount().call().then(function(totalCount){
		//console.log("Total Request since start: ", totalCount);
		return totalCount;
	})
	.then(function(totalCount){
		return myContract.methods.listAllProviders().call().then(function(allproList){
			if(allproList.length > 0) {
				console.log("=====================================================");
				//console.log("-----------------------------------------------------");
				console.log("List all the Providers : <++     ", totalCount, " total in history")
				DisplayNonZeroInList(allproList,'provider');
				// for(var i = 0;i < allproList.length;i++){
				// 	if(allproList[i]['addr'] != 0){
				// 		if(argv['debug']){
				// 			console.log("-----------------------------------------------------");
				// 			console.log("##############: ", i,  allproList[i]);
				// 		} else {
				// 			//simple print:	
				// 			console.log("-----------------------------------------------------");
				// 			console.log("provID = ", allproList[i]['provID']);
				// 			console.log("addr = ", allproList[i]['addr']);
				// 			console.log("available = ", allproList[i]['available']);							
				// 		}
				// 	}
				// }
			}
			else throw 'Get history provider list failed!'		
		})
	})
}
function ListAllRequestsInHistory(){
	
	return myContract.methods.getRequestCount().call().then(function(totalCount){
		//console.log("Total Request since start: ", totalCount);
		return totalCount;
	})
	.then(function(totalCount){
		return myContract.methods.listAllRequests().call().then(function(allReqList){
			if(allReqList.length > 0) {
				console.log("=====================================================");
				//console.log("-----------------------------------------------------");	
				console.log("List all the Requests : <++     ", totalCount, " total in history")
				DisplayNonZeroInList(allReqList,'request');
				// for(var i = 0;i < allReqList.length;i++){
				// 	if(allReqList[i]['addr'] != 0){
				// 		if(argv['debug']){
				// 			console.log("-----------------------------------------------------");
				// 			console.log("##############: ", i, allReqList[i]);
				// 		} else {
				// 			//simple print:						
				// 			console.log("-----------------------------------------------------");
				// 			console.log("reqID = ", allReqList[i]['reqID']);
				// 			console.log("addr = ", allReqList[i]['addr']);
				// 			console.log("provider = ", allReqList[i]['provider']);
				// 			console.log("status = ",  allReqList[i]['status'])							
				// 		}
				// 	}
				// }
			}
			else throw 'Get history provider list failed!'
		})
	})
}
/////////// Display helpers / format ////////////////////////////////////////////////////
function PrintEvent(event){
	if(argv['debug']){	
		console.log("=======================================================  <- Event!");
		console.log(event);
		console.log("=================================================================");
	} else { 
		console.log("=======================================================  <- Event!");
		console.log(event.event, "  ==>  ", event.blockNumber);
		if(event.event == 'SystemInfo')
			console.log("Event: ", web3.utils.hexToAscii(event.returnValues[2]));
		else if(event.event == 'UpdateInfo')
			console.log("Event: ", web3.utils.hexToAscii(event.returnValues[1]));
		else if (event.event == 'PairingInfo')
			console.log("Event: ", web3.utils.hexToAscii(event.returnValues[4]));
		console.log(event.returnValues);
	}
}
function DisplayNonZeroInList(List, type){
	if(type == 'request')
		for(var i = 0;i < List.length;i++){
			if(List[i]['addr'] != 0){
				if(argv['debug']){
					console.log(List[i]);
					console.log("-----------------------------------------------------")
				} else {
					//simple print:
					console.log("reqID = ", List[i]['reqID']);
					console.log("addr = ", List[i]['addr']);
					console.log("provider = ", List[i]['provider']);
					console.log("status = ",  List[i]['status']);
					console.log("-----------------------------------------------------")							
				}
			}
		}
	else if (type == 'provider')
		for (var i = 0;i < List.length ;i++){
			if(List[i]['addr'] != 0){
				if(argv['debug']){
					console.log(List[i]);
					console.log("-----------------------------------------------------")
				} else{
					console.log("provD = ", List[i]['provID']);
					console.log("addr = ", List[i]['addr']);
					console.log("available = ", List[i]['available']);
					console.log("-----------------------------------------------------")
				}
			}
		}
	else throw 'Not supported type for display'	
}
//helper function called by showPools(), using pool to get object List
function ListoutPool(Pool,type){		//--list [--debug]
	//console.log("List out Pool")
	if (type == 'provider'){
		return myContract.methods.listProviders(Pool).call()
		.then(function(proList){
			console.log("-----------------------------------------------------")
			DisplayNonZeroInList(proList,'provider');
		})
	}
	else if (type == 'request'){
		return myContract.methods.listRequests(Pool).call()
		.then(function(pendList){
			console.log("-----------------------------------------------------")
			DisplayNonZeroInList(pendList,'request');
		})
	}
	else throw "Not supported type!"
}