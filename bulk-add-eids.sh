#!/usr/bin/env bash

usage="A tool to bulk add external ids instead of email addresses for SSO
leveraging script ./add-external-id.sh

Usage:
  $0 [-d] [-f] [-p gc_profile] [-a authority] <input_file>

Inputs:
  input_file: CSV file containing user's email address and external id

Flags:
  -d drill mode
  -f force to update external id
  -p Genesys Cloud profile for authentication
  -a SSO authority
"
gc_profile="default"
force_mode=0
eid_auth="www.e-access.att.com/idpentity"
time_zone="America/New_York"

# Reading arguments with getopts options
while getopts ':dfp:a:' OPTION; do
	case "$OPTION" in
	d)
		# drill mode
		drill_mode=1
		;;
	f)
		# force to update external id
		force_mode=1
		;;
	p)
		# gc profile
		gc_profile="$OPTARG"
		;;
	a)
		# SSO authority
		eid_auth="$OPTARG"
		;;
	*)
		# wrong options
		echo "$usage"
		exit 2
		;;
	esac
done

# Remove all options passed by getopts
shift "$((OPTIND - 1))"

#input_file=${1:?"$(echo "$usage")"}
input_file=${1:?"$usage"}

log_fn="${gc_profile}-add-bulk-eids.log"
echo "=== Start time: $(TZ="$time_zone" date +"%Y-%m-%dT%H:%M:%S%Z")" | tee -a "$log_fn"
echo "  = number of users in input file: $(wc -l "$input_file")" | tee -a "$log_fn"

i=0
j=0
start_ts=$(date +%s)
while IFS=',' read -r email eid_value; do
	((i++))
	read -r user_id current_eid_auth current_eid_value < <(gc -p "$gc_profile" scim users list --filter "userName eq $email" --attributes urn:ietf:params:scim:schemas:extension:genesys:purecloud:2.0:User:externalIds | jq -r 'if .totalResults == 1 then .Resources[] | {id, eIdAuthority:."urn:ietf:params:scim:schemas:extension:genesys:purecloud:2.0:User".externalIds[0].authority, eIdValue:."urn:ietf:params:scim:schemas:extension:genesys:purecloud:2.0:User".externalIds[0].value} | "\(.id) \(.eIdAuthority) \(.eIdValue)" else "null null null" end')
	echo "$i. $email,$user_id,$current_eid_auth,$current_eid_value"
	
	if [[ $user_id == "null" ]]; then
		echo -e "skip $i, because user id can't be found against $email\n" | tee -a "$log_fn"
	elif [[ $current_eid_value == "null" || $force_mode -ne 0 ]]; then
		result=$(./add-external-id.sh ${drill_mode:+"-d"} -p "$gc_profile" -a "$eid_auth" "$user_id" "$eid_value")
		exit_code=$?
		if [[ $exit_code -eq 1 ]]; then
			echo -e "[$(TZ="$time_zone" date +"%Y-%m-%dT%H:%M:%S.%3N%Z") $email] ERROR!\n" | tee -a "$log_fn"
			echo -e "exit code: $exit_code\n$result\n" >>"$log_fn"
		elif [[ $exit_code -eq 0 ]]; then
			((j++))
		fi
		echo -e "exit code: $exit_code\n$result\n"
	else
		echo -e "skip $i, because external id for $email exists\n"
	fi
  
done < <(sed -r 's/\r//g;s/^\s*//g;s/\s*,\s*/,/g;s/\s*$//g' "$input_file")
end_ts=$(date +%s)
duration=$((end_ts - start_ts))
rate=0
if [[ $i -gt 0 ]]; then rate=$(echo "scale=3;$duration/$i" | bc); fi

echo "  = number of users handled      : $i" | tee -a "$log_fn"
echo "  = number of users updated      : $j" | tee -a "$log_fn"
echo "  = duration: $duration seconds, handling rate: $rate s/user" | tee -a "$log_fn"
echo "=== End time: $(TZ="$time_zone" date +"%Y-%m-%dT%H:%M:%S%Z")" | tee -a "$log_fn"
echo >>"$log_fn"
