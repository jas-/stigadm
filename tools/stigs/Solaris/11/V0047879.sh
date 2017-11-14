#!/bin/bash

# OS: Solaris
# Version: 11
# Severity: CAT-I
# Class: UNCLASSIFIED
# VulnID: V-47879
# Name: SV-60751r1


# Minimum permissions octal
octal=00640

# Owner
owner="root"

# Group
group="root"

# Global defaults for tool
author=
verbose=0
change=0
restore=0
interactive=0

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
while getopts "ha:cvri" OPTION ; do
  case $OPTION in
    h) usage && exit 1 ;;
    a) author=$OPTARG ;;
    c) change=1 ;;
    v) verbose=1 ;;
    r) restore=1 ;;
    i) interactive=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have an author if we are not restoring or validating
if [[ "${author}" == "" ]] && [[ ${restore} -ne 1 ]] && [[ ${change} -eq 1 ]]; then
  usage "Must specify an author name (use -a <initials>)" && exit 1
fi

print "Not yet implemented" && exit 0
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


# Obtain the audit directory location
audit_loc="$(pfexec auditconfig -getplugin audit_binfile | grep "^Attributes" | cut -d= -f2 | cut -d: -f1)"

# Handle symlinks
audit_loc="$(get_inode ${audit_loc})"

# Validate we have a location & it's valid
if [ ! -d ${audit_loc} ]; then

  # Print friendly message
  [ ${verbose} -eq 1 ] && print "Could not obtain audit location" 1
  exit 1
fi

# Print friendly message
[ ${verbose} -eq 1 ] && print "Obtained audit location"


# If required do work
if [ ${change} -eq 1 ]; then

  # Get the current octal value of ${audit_loc}
  coctal=$(get_octal ${audit_loc})
  
  # Get current owner
  cowner="$(get_inode_user ${audit_loc})"
    
  # Get current group
  cgroup="$(get_inode_group ${audit_loc})"

  # Apply ${octal} if ${coctal} > ${octal}
  if [ ${coctal} -gt ${octal} ]; then

    # Print friendly message
    [ ${verbose} -eq 1 ] && print "Setting '${octal}' on '${audit_loc}'"
    chmod ${octal} ${audit_loc}
  fi

  # Apply ${owner}:${group} if ${cowner} != ${owner} or ${group} != ${cgroup}
  if [[ "${owner}" != "${cowner}" ]] || [[ "${group}" != "${cgroup}" ]]; then

    # Print friendly message
    [ ${verbose} -eq 1 ] && print "Setting '${owner}:${group}' on '${audit_loc}'"
    chown ${owner}:${group} ${audit_loc}
  fi
fi


# Get the current octal value of ${audit_loc}
coctal=$(get_octal ${audit_loc})
  
# Get current owner
cowner="$(get_inode_user ${audit_loc})"

# Get current group
cgroup="$(get_inode_group ${audit_loc})"

# Apply ${octal} if ${coctal} > ${octal}
if [ ${coctal} -gt ${octal} ]; then

  # Print friendly message
  [ ${verbose} -eq 1 ] && print "'${coctal}' is less than '${octal}' on '${audit_loc}'" 1
fi

# Apply ${owner}:${group} if ${cowner} != ${owner} or ${group} != ${cgroup}
if [[ "${owner}" != "${cowner}" ]] || [[ "${group}" != "${cgroup}" ]]; then

  # Print friendly message
  [ ${verbose} -eq 1 ] && print "Invalid ownership on '${audit_loc}' (${cowner}:${cgroup})" 1
fi


# Print friendly success
[ ${verbose} -eq 1 ] && print "Success, conforms to '${stigid}'"

exit 0

# Date: 2017-06-21
#
# Severity: CAT-I
# Classification: UNCLASSIFIED
# STIG_ID: V0047879
# STIG_Version: SV-60751r1
# Rule_ID: SOL-11.1-010460
#
# OS: Solaris
# Version: 11
# Architecture: Sparc
#
# Title: The operating system must protect audit information from unauthorized deletion.
# Description: The operating system must protect audit information from unauthorized deletion.


# Date: 2017-06-21
#
# Severity: CAT-I
# Classification: UNCLASSIFIED
# STIG_ID: V0047879
# STIG_Version: SV-60751r1
# Rule_ID: SOL-11.1-010460
#
# OS: Solaris
# Version: 11
# Architecture: X86
#
# Title: The operating system must protect audit information from unauthorized deletion.
# Description: The operating system must protect audit information from unauthorized deletion.

