# findit.sh

**findit.sh** is a Bash script that uses Spice Labs open source tools to fingerprint and identify. It outputs all locations and containment relationships for files whose content matches the given reference.

---

## Requirements

- **Bash** (Linux or macOS)
- **Docker** (must have: `spicelabs/goatrodeo`, `spicelabs/bigtent`)
- **Tools** inside containers: `md5sum`, `curl`, `jq`
- **Network access to localhost:3000** (used by `bigtent` container)
- Working directory must be empty at start

---

## Usage

`./findit.sh --scan PATH --compare FILE --workdir PATH [--tag TAG] [--help]`


### Options

- **--scan PATH**: Directory to scan artifacts  
- **--compare FILE**: Path to reference file to match by content hash  
- **--workdir PATH**: Working directory for intermediate outputs (*must be empty*)  
- **--help**: Show help and exit  


## How It Works

1. **Argument Checking**
   - Validates all required arguments and their paths (must be absolute or convert to absolute).
2. **Hash Calculation**
   - Calculates the MD5 hash of the reference file to find matching content.
3. **Container Preparation**
   - Pulls required Docker images (`spicelabs/goatrodeo` and `spicelabs/bigtent`).
4. **Artifact Scanning**
   - Runs `goatrodeo` Docker container to scan the directory and output results.
   - Locates the first `.grc` output file.
5. **Analysis with bigtent**
   - Runs `bigtent` as a Docker service to analyze relationships.
   - Uses its API to search for files matching the MD5 hash.
   - Recursively looks up containment relationships to find all top-level files.
6. **Reporting**
   - Lists all discovered matching file paths and containment relationships.
7. **Cleanup**
   - Stops and removes the running `bigtent` service container.

   ## Example

`mkdir /tmp/finder-work`

`./findit.sh --scan /home/user/scan_folder --compare ref.jar --workdir /tmp/finder-work`

---

## Notes

- Working directory (**--workdir**) must be empty before starting. The script checks and aborts if not.
- All output and intermediate files are stored in the working directory.
- If a matching file is not found, the script prints “NOT FOUND IN SCAN”.
- The script requires Docker daemon access and necessary permissions.
- Containers must expose expected command-line and API behavior.

---

## Troubleshooting

- Make sure Docker is running and you have permission to run containers.
- Required ports (esp. 3000) must be free and accessible.
- Respond to any errors about paths or directory emptiness.
- For JSON/jq errors in output, inspect the working directory contents.

---

## License

Apache 2.0

