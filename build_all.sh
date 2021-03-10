#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -o pipefail

# shellcheck source=common_functions.sh
source ./common_functions.sh

dry_run=0
target_repo="${DOCKERHUB_REPO:-adoptopenjdk}/openjdk"
while getopts "ns:j:p:r:" opt; do
  case ${opt} in
    n)
	  dry_run=1
      ;;
	s)
      supported_versions="$OPTARG"
	  ;;
	j)
	  all_jvms="$OPTARG"
	  ;;
	p)
	  all_packages="$OPTARG"
	  ;;
	r)
	  # export for other scripts to use it
	  export DOCKERHUB_REPO="$OPTARG"
	  target_repo="$OPTARG/openjdk"
	  ;;
  esac
done

shift $((OPTIND -1))

if [ ! -z "$1" ]; then
	echo "overriding supported_versions to $1"
	supported_versions="$1"
fi

for ver in ${supported_versions}
do
	for vm in ${all_jvms}
	do
		for package in ${all_packages}
		do
			# Cleanup any old containers and images
			cleanup_images
			cleanup_manifest

			# Remove any temporary files
			rm -f hotspot_*_latest.sh openj9_*_latest.sh push_commands.sh

			echo "=========================================================================================="
			echo "                                                                                          "
			echo "  $(date +%T) :    Building Docker Images for Version ${ver} ${vm} ${package} ${runtype}  "
			echo "                                                                                          "
			echo "=========================================================================================="
			./build_latest.sh "${ver}" "${vm}" "${package}" "${runtype}"

			err=$?
			if [ ${err} != 0 ] || [ ! -f ./push_commands.sh ]; then
				echo "###############################################################"
				echo
				echo "ERROR: Docker Build for Version ${ver} ${vm} ${package} failed."
				echo
				echo "###############################################################"
			fi
			if [ ${dry_run} != 1 ]; then
				echo
				echo "WARNING: Pushing to AdoptOpenJDK repo on hub.docker.com"
				echo "WARNING: If you did not intend this, quit now. (Sleep 5)"
				echo
				sleep 5
				# Now push the images to hub.docker.com
				echo "==============================================================================="
				echo "                                                                               "
				echo "  $(date +%T) :    Pushing Docker Images for Version ${ver} ${vm} ${package}   "
				echo "                                                                               "
				echo "==============================================================================="
				cat push_commands.sh
				./push_commands.sh
			fi

			# Remove any temporary files
			rm -f hotspot_*_latest.sh openj9_*_latest.sh push_commands.sh

			if [ ${dry_run} != 1 ]; then
				# Now test the images from hub.docker.com
				echo "==============================================================================="
				echo "                                                                               "
				echo "  $(date +%T) :    Testing Docker Images for Version ${ver} ${vm} ${package}   "
				echo "                                                                               "
				echo "==============================================================================="
				# Only test the individual docker image tags and not the aliases
				# as the aliases are not created yet.
				echo "test_tags" > ${test_image_types_file}
				./test_multiarch.sh "${ver}" "${vm}" "${package}"
			fi
		done
	done
done

# Cleanup any old containers and images
cleanup_images
cleanup_manifest
