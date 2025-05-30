# Getting The OstrichDB NLP Module Working

# Importing Golang Code Into Odin Code For OstrichDB

## Setup

1. Ensure you have Go Installed and Setup properly
2. Run `go mod init main` (optional if the project is not already initialized)
3. Run `go mod tidy` to install dependencies(optional since there are no dependencies at this point)
4. Run `go build -buildmode c-shared -o nlp.dylib`(For macOS) **Note:** Ensure the package name in your go file is `main`
5. Run `odin build nlp.odin -file` (For macOS)
6. Run OstrichDB from the projects root `dir`:
``` bash
./scripts/local_build_run.sh
```


**Note:** When you make changes to either the Go or Odin code, you need to delete the following files:
- `nlp.dylib` (For macOS)
- `nlp.h` (For all platforms)
- `nlp` Or whatever executable file Odin built
  To do this just run: `python3 delete_trash.py`


- Ensure the Go `main.go` file is importing `"C"`
- When running GO within Odin the nlp.dylib file needs to be in the bin dir otherwise shit wont work
- Ensure the SYS_INSTRUCTIONS file is in the nlp directory during compile time

Then you need to re-run steps 4 and 5 from above.

This file and its instructions will change as the project evolves. These are just my notes on how I got this working.
