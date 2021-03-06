#!/bin/bash


# Define an array of required services
declare -a services
services+=("svc:/network/ipsec/policy:default")


# Global defaults for tool
author=
change=0
json=1
meta=0
restore=0
interactive=0
xml=0


# Working directory
cwd="$(dirname $0)"

# Tool name
prog="$(basename $0)"


# Copy ${prog} to DISA STIG ID this tool handles
stigid="$(echo "${prog}" | cut -d. -f1)"


# Ensure path is robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin


# Define the library include path
lib_path=${cwd}/../../../libs

# Define the tools include path
tools_path=${cwd}/../../../stigs

# Define the system backup path
backup_path=${cwd}/../../../backups/$(uname -n | awk '{print tolower($0)}')


# Robot, do work


# Error if the ${inc_path} doesn't exist
if [ ! -d ${lib_path} ] ; then
  echo "Defined library path doesn't exist (${lib_path})" && exit 1
fi


# Include all .sh files found in ${lib_path}
incs=($(ls ${lib_path}/*.sh))

# Exit if nothing is found
if [ ${#incs[@]} -eq 0 ]; then
  echo "'${#incs[@]}' libraries found in '${lib_path}'" && exit 1
fi


# Iterate ${incs[@]}
for src in ${incs[@]}; do

  # Make sure ${src} exists
  if [ ! -f ${src} ]; then
    echo "Skipping '$(basename ${src})'; not a real file (block device, symlink etc)"
    continue
  fi

  # Include $[src} making any defined functions available
  source ${src}

done


# Ensure we have permissions
if [ $UID -ne 0 ] ; then
  usage "Requires root privileges" && exit 1
fi


# Set variables
while getopts "ha:cjmvrix" OPTION ; do
  case $OPTION in
    h) usage && exit 1 ;;
    a) author=$OPTARG ;;
    c) change=1 ;;
    j) json=1 ;;
    m) meta=1 ;;
    r) restore=1 ;;
    i) interactive=1 ;;
    x) xml=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have an author if we are not restoring or validating
if [[ "${author}" == "" ]] && [[ ${restore} -ne 1 ]] && [[ ${change} -eq 1 ]]; then
  usage "Must specify an author name (use -a <initials>)" && exit 1
fi


# If ${meta} is true
if [ ${meta} -eq 1 ]; then

  # Print meta data
  get_meta_data "${cwd}" "${prog}"
fi


# Make sure a service is defined
if [ ${#services[@]} -eq 0 ]; then

  # Print friendly message
  usage "At least one configured service must be defined"
fi


# If ${restore} = 1 go to restoration mode
if [ ${restore} -eq 1 ]; then

  # If ${interactive} = 1 go to interactive restoration mode
  if [ ${interactive} -eq 1 ]; then

    # Print friendly message regarding restoration mode
    [ ${verbose} -eq 1 ] && print "Interactive restoration mode for '${file}'"

  fi

  # Print friendly message regarding restoration mode
  [ ${verbose} -eq 1 ] && print "Restored '${file}'"

  exit 0
fi


# Get list of services that are enabled
svcs_list=($(svcs -a | grep ^online | sort -k3 | awk '{print $3}'))

# Iterate ${services[@]}
for service in ${services[@]}; do

  # Check to see if ${service} exists in ${svcs_list[@]}
  if [ $(in_array "${service}" "${svcs_list[@]}") -eq 1 ]; then

    # If ${change} = 1
    if [ ${change} -eq 1 ]; then

      # Enable ${service}
      svcadm enable ${service} &> /dev/null
      [ $? -ne 0 ] && print "An error occured enabling '${service}'" 1

      # Print friendly message regarding restoration mode
      [ ${verbose} -eq 1 ] && print "Enabled '${service}'"
    fi
  fi
done


# Set a default return value
ret=0

# Get list of services that are enabled
svcs_list=($(svcs -a | grep ^online | sort -k3 | awk '{print $3}'))

# Iterate ${services[@]}
for service in ${services[@]}; do

  # Check to see if ${service} exists in ${svcs_list[@]}
  if [ $(in_array "${service}" "${svcs_list[@]}") -ne 0 ]; then

    # Print friendly message regarding restoration mode
    [ ${verbose} -eq 1 ] && print "'${service}' is not enabled"
    ret=1
  fi
done


# Exit if errors occurred
[ ${ret} -eq 1 ] && exit 1


# Print friendly success
[ ${verbose} -eq 1 ] && print "Success, conforms to '${stigid}'"

exit 0

# Date: 2018-09-05
#
# Severity: CAT-II
# Classification: UNCLASSIFIED
# STIG_ID: V0048141
# STIG_Version: SV-61013r1
# Rule_ID: SOL-11.1-060190
#
# OS: Solaris
# Version: 11
# Architecture: Sparc X86
#
# Title: The operating system must protect the integrity of transmitted information.
# Description: Ensuring the integrity of transmitted information requires the operating system take feasible measures to employ transmission layer security. This requirement applies to communications across internal and external networks.
