# /bin/bash

#Copyright [2025] [Spice Labs, Inc.]

#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

show_help() {
  cat <<EOF
Usage: findit --scan <path> --compare <file> --workdir <path> 

Options:
  --scan PATH            Where to scan artifacts
  --compare FILE         Path to file that is the reference we are looking for
  --workdir PATH         Working directory where should store intermediate outputs. It should be empty.
  --help                 Show this help
EOF
}

GOAT_DOCKER="spicelabs/goatrodeo"
BIGTENT_DOCKER="spicelabs/bigtent"
CONTAINER_ID=""
declare -a FILE_RESULTS


get_compare_hash(){
    echo "$compare"
    hash_to_find=$(md5sum "$compare" | awk '{print $1}')
    echo "hash to find is: $hash_to_find"
}

get_docker_images(){
    #docker pull "$DOCKER_IMAGE" > /dev/null
    docker pull "$GOAT_DOCKER"
    docker pull "$BIGTENT_DOCKER"
}

run_goatrodeo(){
  docker run -it --rm -v "$scan":/tmp/scan -v "$workdir":/tmp/output $GOAT_DOCKER -b /tmp/scan -o /tmp/output --tag "$tag"
}

find_grc(){
    grcfile=$(find "$workdir" -type f -name '*.grc' -print -quit)

    if [ -n "$grcfile" ]; then
        echo "First .grc file found: $grcfile"
    else
        echo "No .grc files found in $workdir. Nothing to compare, exiting"
        exit 1
    fi
    #grcfile=$(basename "$grcfile")
    #echo "$grcfile"
}

run_bigtent(){
   the_file=$(basename $grcfile)
   CONTAINER_ID=$(docker run -d -v "$workdir":/tmp/workdir -p 3000:3000 --platform linux/amd64 $BIGTENT_DOCKER  -r "/tmp/workdir/$the_file" --host 0.0.0.0)
   echo "Waiting for big tent to start"
   sleep 5
   #let it get started
}
# Function to clean up the process
cleanup() {
    docker stop "$CONTAINER_ID" > /dev/null
    docker rm "$CONTAINER_ID" > /dev/null
    echo "do cleanup"
}



do_curl(){
    echo "$hash_to_find"
    #make sure bigtent got started
    
    url="http://localhost:3000/omnibor/aa/md5:$hash_to_find" 
    secondcall="jq -r '(.connections? // [])[] | select(.[0] == "contained:up") | .[1]'"
    deeperurl="http://localhost:3000/omnibor/north/"
    # Capture the output of curl into a variable
    response=$(curl -s "$url")
    
    substring="body"

    if [[ "$response" == *"$substring"* ]]; then
        echo "Found the file looking upstream"
        #nextresponse=$(curl -s "$url")
        echo "Looking to see if this is a top level file already. Ignore jq error"
        curl -s "$url" | \
          tr -d '\000-\010\013\014\016-\037' | \
          jq -r '.[] | select(all(.connections[]; .[0] != "contained:up")) | .body.file_names[]'
        
        echo "Looking for ups"
        contained=$(curl -s "$url" | \
          tr -d '\000-\010\013\014\016-\037' | \
          jq -r '(.connections? // [])[] | select(.[0] == "contained:up") | .[1]')

        while IFS= read -r gitoid; do
           echo "Processing gitoid: $gitoid"
           check_contained "$gitoid"
        done <<< "$contained"
        #echo "$deeperurl$gitoid_up"
        #upstream_response=$(curl -s "$deeperurl$gitoid_up")
        #echo "$upstream_response"
    else
        echo "NOT FOUND IN SCAN"
    fi

    # Print the captured output
   # echo "$response"
}

check_contained(){
    url="http://localhost:3000/north/$1"
    echo "$url"
   
    #read -p "Press Enter to continue"
    #let's see if any filenames
    # shellcheck disable=SC2046
    filecheck=$(curl -s "$url" | \
            tr -d '\000-\010\013\014\016-\037' | \
            jq -r '.[] | select(all(.connections[]; .[0] != "contained:up")) | .body.file_names[]' )
    
    if [[ "$filecheck" == *"jq"* ]]; then
      echo "no top level files in this level"
    else
      while IFS= read -r fname; do
           echo "Found: $fname"
           FILE_RESULTS+=("$fname")
        done <<< "$filecheck"
    fi

    #now see if more walking up to do
    contained=$(curl -s "$url" | \
          tr -d '\000-\010\013\014\016-\037' | \
          jq -r '(.connections? // [])[] | select(.[0] == "contained:up") | .[1]')

    if [ -n "$contained" ]; then
        while IFS= read -r gitoid; do
           echo "Processing gitoid: $gitoid"
           check_contained "$gitoid"
        done <<< "$contained"
    fi
}

print_results(){
  
  echo "-----------------------------------------"
  echo "Here are the locations we identified contained:$compare"
  echo ""
  if [ "${#FILE_RESULTS[@]}" -gt 0 ]; then
    for element in "${FILE_RESULTS[@]}"; do
        echo "$element"
    done
  fi
  

}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan)
      scan="$2"
      shift 2
      ;;
    --compare)
      compare="$2"
      shift 2
      ;;
    --workdir)
      workdir="$2"
      shift 2
      ;;
    --ignore)
      ignore="$2"
      shift 2
      ;;
    --tag)
      tag="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

if [ ! -d "$scan" ]; then
  echo "$scan does not exist."
  echo ""
  show_help
  exit 0
else
  #we know it exists make sure we have absolute path
  scan=$(realpath $scan)
fi

if [ ! -f "$compare" ]; then
    echo "$compare not found!"
    echo ""
    show_help
    exit 0
else 
  #we know it exists make sure we have absolute path
  compare=$(realpath $compare)
fi

if [ ! -d "$workdir" ]; then
  echo "$workdir does not exist."
  echo ""
  show_help
  exit 0
else
  #we know it exists make sure we have absolute path
  workdir=$(realpath $workdir)
fi

if [ -z "$( ls -A $workdir )" ]; then
   echo "$workdir empty continuing...."
else
   echo "$workdir Not Empty"
   echo ""
   show_help
   exit 0
fi

get_compare_hash
get_docker_images
run_goatrodeo
find_grc
run_bigtent
do_curl
cleanup
print_results
