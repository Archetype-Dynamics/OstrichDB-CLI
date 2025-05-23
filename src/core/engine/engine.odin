package engine

import "../../utils"
import "../const"
import "../server"
import "../types"
import "./config"
import "./data"
import "./data/metadata"
import "./security"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "../nlp"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Contributors:
    @CobbCoding1

License: Apache License 2.0 (see LICENSE file for details)
Copyright (c) 2024-2025 Marshall A Burns and Solitude Software Solutions LLC
Copyright (c) 2025-Present Archetype Dynamics, Inc.

File Description:
            Contains logic for the OstrichDB engine, including the command line,
            session timer, and command history updating. Also contains
            logic for re-starting/re-building the engine as well as
            initializing the data integrity system.
*********************************************************/


//initialize the data integrity system
INIT_DATA_INTEGRITY_CHECK_SYSTEM :: proc(checks: ^types.Data_Integrity_Checks) -> (success: int) {
	using types

	data_integrity_checks.File_Size.Severity = .LOW
	data_integrity_checks.File_Format_Version.Severity = .MEDIUM
	data_integrity_checks.Cluster_IDs.Severity = .HIGH
	data_integrity_checks.Data_Types.Severity = .HIGH
	data_integrity_checks.File_Format.Severity = .HIGH

	data_integrity_checks.File_Size.Error_Message =
	"Collection file size is larger than the maxmimum size of 10mb"
	data_integrity_checks.File_Format.Error_Message =
	"A formatting error was found in the collection file"
	data_integrity_checks.File_Format_Version.Error_Message =
	"Collection file format version is not compliant with the current version"
	data_integrity_checks.Cluster_IDs.Error_Message = "Cluster ID(s) not found in cache"
	data_integrity_checks.Data_Types.Error_Message =
	"Data type(s) found in collection are not approved"
	return 0

}

//Starts the OstrichDB engine:
//Session timer, sign in, and command line
START_OSTRICHDB_ENGINE :: proc() -> int {
	using const
	using types

	//Initialize data integrity system
	INIT_DATA_INTEGRITY_CHECK_SYSTEM(&data_integrity_checks)
	switch (OstrichEngine.Initialized)
	{
	case false:
		//Continue with engine initialization
		security.HANDLE_FIRST_TIME_ACCOUNT_SETUP()
		break

	case true:
		for {
			userSignedIn := security.RUN_USER_SIGNIN()
			switch (userSignedIn)
			{
			case true:
				security.START_SESSION_TIMER()
				utils.log_runtime_event(
					"User Signed In",
					"User successfully logged into OstrichDB",
				)
				currentUserName:= current_user.username.Value
				systemUserMK := system_user.m_k.valAsBytes
				//Check to see if the server AUTO_SERVE config value is true. If so start server
				security.TRY_TO_DECRYPT(currentUserName, .USER_CONFIG_PRIVATE, systemUserMK)
				autoServeConfigValue := data.GET_RECORD_VALUE(
					utils.concat_user_config_collection_name(currentUserName),
					utils.concat_user_config_cluster_name(currentUserName),
					Token[.BOOLEAN],
					AUTO_SERVE,
				)
				if strings.contains(autoServeConfigValue, "true") {
					fmt.println("The OstrichDB server is starting...\n")
					fmt.println(
						"If you do not want the server to automatically start by default follow the instructions below:",
					)
					fmt.println(
						"1. Enter 'kill' or 'quit' to stop the server and be returned to the OstrichDB command line",
					)
					fmt.println("2. Use command: 'SET CONFIG AUTO_SERVE TO false'\n\n")
					security.ENCRYPT_COLLECTION(currentUserName, .USER_CONFIG_PRIVATE, systemUserMK)

					//Auto-server loop
					serverDone := server.START_OSTRICH_SERVER(&OstrichServer)
					if serverDone == 0 {
						fmt.println("\n\n")
						cmdLineDone := START_COMMAND_LINE()
						if cmdLineDone == 0 {
							return cmdLineDone
						}
					}

				} else {
					// if the AUTO_SERVE config value is false, then continue starting command line
					security.ENCRYPT_COLLECTION(currentUserName, .USER_CONFIG_PRIVATE, systemUserMK)

					fmt.println("Starting command line")
					result := START_COMMAND_LINE()
					return result
				}
			case false:
				fmt.printfln("%sSign-in failed.%s  Please try again.", utils.RED, utils.RESET)
				return 1
			}
		}
	}
	return 0
}

//Command line loop
START_COMMAND_LINE :: proc() -> int {
    using const
    using types
    using security

	result := 0
	fmt.println("Welcome to the OstrichDB DBMS Command Line")
	utils.log_runtime_event("Entered DBMS command line", "")
	for USER_SIGNIN_STATUS == true {
		//Command line start
		buf: [1024]byte

		fmt.print(ostCarrat, "\t")

		input := utils.get_input(false)
		currentUserName := current_user.username.Value
		systemUserMK := system_user.m_k.valAsBytes

		TRY_TO_DECRYPT(currentUserName, .USER_HISTORY_PRIVATE, systemUserMK)
		APPEND_COMMAND_TO_HISTORY(input)
		ENCRYPT_COLLECTION(currentUserName, .USER_HISTORY_PRIVATE, systemUserMK)
		cmd := PARSE_COMMAND(input)
		// fmt.println("DEBUG: cmd: ", cmd) //Debugging DO NOT DELETE


		//check if  the LIMIT_SESSION_TIME config is enabled.
		TRY_TO_DECRYPT(currentUserName, .USER_CONFIG_PRIVATE, systemUserMK)
		sessionLimitValue:= data.GET_RECORD_VALUE(utils.concat_user_config_collection_name(currentUserName),utils.concat_user_config_cluster_name(currentUserName) ,Token[.BOOLEAN],LIMIT_SESSION_TIME)
		ENCRYPT_COLLECTION(currentUserName, .USER_CONFIG_PRIVATE, systemUserMK)

		if sessionLimitValue == "true"{
		  //Check to ensure that BEFORE the next command is executed, the max session time hasnt been met
		  sessionDuration := GET_SESSION_DURATION()
		  maxDurationMet := CHECK_IF_SESSION_DURATION_MAXED(sessionDuration)
		  switch (maxDurationMet)
		  {
		  case false:
		      break
		  case true:
		      HANDLE_MAXED_SESSION()
		  }
		}
		result = EXECUTE_COMMAND(&cmd)
	}

	//Re-engage the loop
	if USER_SIGNIN_STATUS == false {
		// security.DECRYPT_COLLECTION("", .CONFIG_PRIVATE, system_user.m_k.valAsBytes)
		START_OSTRICHDB_ENGINE()
	}

	return result
}

//Used to restart the engine
RESTART_OSTRICHDB :: proc() {
	if const.DEV_MODE == true {
		libc.system(const.RESTART_SCRIPT_PATH)
		os.exit(0)
	} else {
		fmt.println("Using the RESTART command is only available in development mode.")
	}
}

//Used to rebuild then restart the engine
REBUILD_OSTRICHDB :: proc() {
	if const.DEV_MODE == true {
		libc.system(const.BUILD_SCRIPT_PATH)
		os.exit(0)
	} else {
		fmt.println("Using the REBUILD command is only available in development mode.")
	}
}
