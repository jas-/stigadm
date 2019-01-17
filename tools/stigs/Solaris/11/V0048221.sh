#!/bin/bash

# Define an array of exceptions
declare -a exceptions
exceptions+=("10.0.2.18")

# Define the hosts.allow path
hosts_allow=/etc/hosts.allow

# Define the hosts.allow path
hosts_deny=/etc/hosts.deny

# Define a template
read -d '' wrapper_tpl <<"EOF"
ALL:{RANGE}
EOF


###############################################
# Bootstrapping environment setup
###############################################

# Get our working directory
cwd="$(pwd)"

# Define our bootstrapper location
bootstrap="${cwd}/tools/bootstrap.sh"

# Bail if it cannot be found
if [ ! -f ${bootstrap} ]; then
  echo "Unable to locate bootstrap; ${bootstrap}" && exit 1
fi

# Load our bootstrap
source ${bootstrap}


###############################################
# Metrics start
###############################################

# Get EPOCH
s_epoch="$(gen_epoch)"

# Create a timestamp
timestamp="$(gen_date)"

# Whos is calling? 0 = singular, 1 is from stigadm
caller=$(ps -p $PPID | grep -c stigadm)


###############################################
# STIG validation/remediation/restoration
###############################################

# Current value of inetadm for inetd? false/true
curr_inetd=$(inetadm -p|grep tcp_wrappers|grep -c FALSE)

# If ${curr_inetd} > 0 add to ${errors[@]} array
[ ${curr_inetd} -gt 0 ] &&
  errors+=("svc:/network/inetd:tcp_wrappers:FALSE")


# Gather up all of our possible services (legacy & modern)
services=( $(svcs -a | awk 'NR>1 && $3 ~ /svc:\//{print $3}' | sort | sed "s|:default||g")
           $(inetadm | awk '/svc:\//{print $NF}' | sort) )

# Filter ${servcies[@]} for those with a tcp_wrapper option
for service in ${services[@]}; do

  # Get service & configuration item name if matched
  item="$(svccfg -s ${service} listprop 2>/dev/null | grep tcp | grep boolean |
    awk '$1 ~ /wrappers$/{print}' | grep false |
    nawk -v svc="${service}" '{printf("%s:%s:%s\n", svc, $1, $3)}')"

  # Bail if ${item} isn't null
  if [ "${item}" != "" ]; then
    errors+=("${item}")
    continue
  fi

  # If ${item} is null try ${service}:default configuration values
  [ "${item}" == "" ] &&
    item="$(svccfg -s ${service}:default listprop 2>/dev/null | grep tcp | grep boolean |
      awk '$1 ~ /wrappers$/{print}' | grep false |
      nawk -v svc="${service}" '{printf("%s:%s:%s\n", svc, $1, $3)}')"

  # Bail if ${item} isn't null
  if [ "${item}" != "" ]; then
    errors+=("${item}")
    continue
  fi

  # If ${item} is still null assume legacy and switch to inetadm
  [ "${item}" == "" ] &&
    item="$(inetadm -l ${service} 2>/dev/null | grep tcp_wrappers | grep FALSE |
      nawk -v svc="${service}" '{gsub(/\=/, ":", $NF);printf("%s:%s\n", svc, $NF)}')"

  # If ${item} isn't null add to ${errors[@]}
  [ "${item}" != "" ] && errors+=("${item}")
done


# Acquire current IPv4 & IPv6 addresses
interfaces=( $(get_ipv4) $(get_ipv6) )

# Get array of current configurations from ${hosts_allow}
curr_allow=( $(awk '$1 ~ /^[0-9|a-zA-Z]+\:|[ALL|LOCAL|*KNOWN|PARANOID]\:.*/{print}' ${hosts_allow} 2>/dev/null |tr ' ' '_') )


# Iterate ${interfaces[@]}
for interface in ${interfaces[@]}; do

  # Cut out IPv4/IPv6 from ${interface}
  ip="$(echo "${interface}" | cut -d, -f2)"
  mask="$(echo "${interface}" | cut -d, -f3)"

  # If ${ip} & ${mask} are IPv4
  if [[ $(is_ipv4 "${ip}") -eq 0 ]] && [[ $(is_ipv4 "${mask}") -eq 0 ]]; then

    # Calculate the range for current ${interface} & number of nodes
    range=$(calc_ipv4_hosts_per_subnet "${mask}")
    cidr=$(calc_ipv4_cidr "${mask}")

    # Iterate ${curr_allow[@]}
    for current in ${curr_allow[@]}; do

      # Cut out possible IPv4 address
      # FIX: Use REGEX to acquire possible IPv4/IPv6 or RFC based hostname
      parsed_ip="$(echo "${current}" | nawk -F: '{print $NF}')"

      # Normalize ${curr_ip}
      normalized="$(normalize_ipv4 "${parsed_ip}")"

      if [ $(echo "${normalized}" | grep -c ",") -gt 0 ]; then
        acl_mask="$(echo "${normalized}" | cut -d, -f2)"
        normalized="$(echo "${normalized}" | cut -d, -f1)"

        # Get the range from ${normalized}
        cur_range=$(calc_ipv4_hosts_per_subnet "${acl_mask}")
      else
        # Get the range from ${normalized}
        cur_range=$(calc_ipv4_hosts_per_subnet "${normalized}")
      fi

      # Compare ${normalized} w/ ${ip} & ${mask} for range comparison
      in_range=$(calc_ipv4_host_in_range "${ip}" "${mask}" "${normalized}")

      str_int="Internal:${parsed_ip}:${cur_range}:Proposed:${ip}/${cidr}:${range}"
      str_ext="External:${parsed_ip}:${cur_range}"
      str_excl="[Excluded]"

      # If ${in_range} & ${cur_range} > ${range} flag as an error
      if [[ "${in_range}" == "true" ]] && [[ ${cur_range} -gt ${range} ]]; then
        [ $(in_array "${normalized}" "${exceptions[@]}") -eq 0 ] &&
          errors+=("${str_excl}:${str_int}") || errors+=("${str_int}")
      fi

      # If ${in_range} is false
      if [ "${in_range}" == "false" ]; then
        [ $(in_array "${normalized}" "${exceptions[@]}") -eq 0 ] &&
          errors+=("${str_excl}:${str_ext}") || errors+=("${str_ext}")
      fi

      # Mark evertyhing as inspected
      if [ "${in_range}" == "true" ]; then
        [ $(in_array "${normalized}" "${exceptions[@]}") -eq 0 ] &&
          inspected+=("${str_excl}:${str_int}") || inspected+=("${str_int}")
      else
        [ $(in_array "${normalized}" "${exceptions[@]}") -eq 0 ] &&
          inspected+=("${str_excl}:${str_ext}") || inspected+=("${str_ext}")
      fi
    done
  fi
done


# Ensure ${hosts_deny} is indeed DENY by default

# If ${change} is enabled

# Make backup of both ${hosts_allow} & ${hosts_deny}

# Iterate ${errors[@]} & add to ${hosts_allow}

# Re-write ${hosts_deny} as ALL:ALL (deny by default)

# Refresh ${errors[@]} array


# Remove dupes and sort ${errors[@]}
errors=( $(remove_duplicates "${errors[@]}") )

# Copy ${services[@]} array to ${inspected[@]}
inspected=( $(remove_duplicates "${inspected[@]}") )
inspected+=( $(remove_duplicates "${services[@]}") )


###############################################
# Results for printable report
###############################################

# If ${#errors[@]} > 0
if [ ${#errors[@]} -gt 0 ]; then

  # Set ${results} error message
  results="Failed validation"
fi

# Set ${results} passed message
[ ${#errors[@]} -eq 0 ] && results="Passed validation"


###############################################
# Report generation specifics
###############################################

# Apply some values expected for report footer
[ ${#errors[@]} -eq 0 ] && passed=1 || passed=0
[ ${#errors[@]} -gt 0 ] && failed=1 || failed=0

# Calculate a percentage from applied modules & errors incurred
percentage=$(percent ${passed} ${failed})

# If the caller was only independant
if [ ${caller} -eq 0 ]; then

  # Show failures
  [ ${#errors[@]} -gt 0 ] && print_array ${log} "errors" "${errors[@]}"

  # Provide detailed results to ${log}
  if [ ${verbose} -eq 1 ]; then

    # Print array of failed & validated items
    [ ${#inspected[@]} -gt 0 ] && print_array ${log} "validated" "${inspected[@]}"
  fi

  # Generate the report
  report "${results}"

  # Display the report
  cat ${log}
else

  # Since we were called from stigadm
  module_header "${results}"

  # Show failures
  [ ${#errors[@]} -gt 0 ] && print_array ${log} "errors" "${errors[@]}"

  # Provide detailed results to ${log}
  if [ ${verbose} -eq 1 ]; then

    # Print array of failed & validated items
    [ ${#inspected[@]} -gt 0 ] && print_array ${log} "validated" "${inspected[@]}"
  fi

  # Finish up the module specific report
  module_footer
fi


###############################################
# Return code for larger report
###############################################

# Return an error/success code (0/1)
exit ${#errors[@]}


# Date: 2018-09-05
#
# Severity: CAT-III
# Classification: UNCLASSIFIED
# STIG_ID: V0048221
# STIG_Version: SV-61093r1
# Rule_ID: SOL-11.1-050140
#
# OS: Solaris
# Version: 11
# Architecture: Sparc X86
#
# Title: The system must implement TCP Wrappers.
# Description: The system must implement TCP Wrappers.
