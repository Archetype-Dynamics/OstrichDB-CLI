package help

import "../../utils"
import "../const"
import "../engine/config"
import "../engine/data"
import "../types"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB
License: Apache License 2.0 (see LICENSE file for details)
Copyright (c) 2024-2025 Marshall A Burns and Solitude Software Solutions LLC
Copyright (c) 2025-Present Archetype Dynamics, Inc.

File Description:
            Implements the HELP command, allowing
            users to get help with OstrichDB commands.
            Reads from the help files in the ../docs directory.
*********************************************************/


validCommands := []string {
	"HELP",
	"LOGOUT",
	"EXIT",
	"REBUILD",
	"RESTART",
	"VERSION",
	"CLEAR",
	"BACKUP",
	"COLLECTION",
	"CLUSTER",
	"RECORD",
	"NEW",
	"ERASE",
	"RENAME",
	"FETCH",
	"TO",
	"COUNT",
	"SET",
	"PURGE",
	"SIZE_OF",
	"TYPE_OF",
	"CHANGE_TYPE",
	"DESTROY",
	"ISOLATE", //formerly known as "QUARANTINE"
	"TREE",
	"HISTORY",
	"WHERE",
	"VALIDATE",
	"BENCHMARK",
	"IMPORT",
	"EXPORT",
	"LOCK",
	"UNLOCK",
	"ENC",
	"DEC",
	"CLP",
	"CLPS",
	"SERVE",
	"SERVER",
	"AGENT",
	"WHERE"
}
//called when user only enters the "HELP" command without any arguments
// will take in the value from the config file. if verbose is true then show data from verbose help file, and vice versa
SET_HELP_MODE :: proc() -> bool {
	using const
	using types
	using utils

	userName:= types.current_user.username.Value
	value := data.GET_RECORD_VALUE(utils.concat_user_config_collection_name(userName), utils.concat_user_config_cluster_name(userName), Token[.BOOLEAN], HELP_IS_VERBOSE)

	switch (value)
	{
	case "true":
		helpMode.isVerbose = true
		break
	case "false":
		helpMode.isVerbose = false
		break
	case:
		fmt.println(
			"Invalid value detected in config file.\n Please delete the ./bin/private/config.ostrichdb file and rebuild OstrichDB.",
		)
	}

	return helpMode.isVerbose
}

//checks if the token that the user wants help with is valid
CHECK_IF_HELP_EXISTS_FOR_TOKEN :: proc(cmd: string) -> bool {
	cmdUpper := strings.to_upper(cmd)
	for validCmd in validCommands {
		if cmdUpper == validCmd {
			return true
		}
	}
	return false
}

//Returns a specific portion of the help file based on the subject passed. can be simple or verbose
GET_HELP_INFO_FOR_SPECIFIC_TOKEN :: proc(subject: string) -> string {
	using const
	using utils

	helpModeIsVerbose := SET_HELP_MODE()
	fmt.printfln("Help mode is verbose: %v", helpModeIsVerbose)
	helpText: string
	data: []byte
	ok: bool

	validCommnad := CHECK_IF_HELP_EXISTS_FOR_TOKEN(subject)
	if !validCommnad {
		fmt.printfln(
			"Cannot get help with %s%s%s as it is not a valid command.\nPlease try valid OstrichDB commmand\nor enter 'HELP' with no trailing arguments",
			BOLD_UNDERLINE,
			subject,
			RESET,
		)
		return ""
	}
	switch (helpModeIsVerbose)
	{
	case true:
		data, ok = os.read_entire_file(VERBOSE_HELP_FILE)
		break
	case false:
		data, ok = os.read_entire_file(SIMPLE_HELP_FILE)
	}
	if !ok {
		return ""
	}
	defer delete(data)

	content := string(data)
	helpSectionStart := fmt.tprintf("### %s START", subject)
	helpSectionEnd := fmt.tprintf("### %s END", subject)

	startIndex := strings.index(content, helpSectionStart)
	if startIndex == -1 {
		return fmt.tprintf("No help found for %s%s%s", BOLD_UNDERLINE, subject, RESET)
	}

	startIndex += len(helpSectionStart)
	endIndex := strings.index(content[startIndex:], helpSectionEnd)
	if endIndex == -1 {
		return fmt.tprintf("Malformed help section for %s%s%s", BOLD_UNDERLINE, subject, RESET)
	}

	helpText = strings.trim_space(content[startIndex:][:endIndex])
	fmt.printfln("\n")
	fmt.printfln(helpText)
	fmt.printfln("\n")
	return strings.clone(helpText)
}

//ready and returns everything from the general help file
GET_GENERAL_HELP_INFO :: proc() -> string {
	using const

	data, ok := os.read_entire_file(GENERAL_HELP_FILE)
	if !ok {
		return ""
	}
	defer delete(data)
	content := string(data)
	fmt.printfln("\n")
	fmt.printfln(content)
	fmt.printfln("\n")
	return strings.clone(content)
}

//shows a table of explaining CLPs
SHOW_TOKEN_HELP_TABLE :: proc() -> string {
	using const

	data, ok := os.read_entire_file(CLPS_HELP_FILE)
	if !ok {
		return ""
	}
	defer delete(data)
	content := string(data)
	fmt.printfln("\nHere is a helpful table containing information about CLPs in OstrichDB:")
	fmt.printfln(
		"--------------------------------------------------------------------------------------------------------------------",
	)
	fmt.println(content)
	fmt.printfln("\n")
	return strings.clone(content)
}
