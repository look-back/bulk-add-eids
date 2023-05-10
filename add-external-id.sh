#!/usr/bin/env bash

usage="A tool to add external id instead of email for SSO
leveraging Genesys Cloud CLI (gc) and JSon processor (jq)

Usage: 
$0 [-d] [-p gc_profile] [-a authority] <user_id> <external_id>

Inputs:
  user_id    : Genesys Cloud user id
  external_id: external id for SSO

Flags:
  -d drill mode
  -p Genesys Cloud profile for authentication
  -a SSO authority

Required Genesys Cloud Permissions:
  directory:user:edit
  directory:user:setPassword
  authorization:grant:add
  authorization:grant:delete
  routing:skill:assign
  routing:language:assign
"
drill_mode=0
gc_profile="default"
eid_auth="my.provider.com/identity"
exit_code=3

# Reading arguments with getopts options
while getopts ':dp:a:' OPTION; do
	case "$OPTION" in
	d)
		# drill mode
		drill_mode=1
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

user_id=${1:?"$usage"}
eid_value=${2:?"$usage"}

update_data='
{
  "schemas": [ "urn:ietf:params:scim:api:messages:2.0:PatchOp" ],
  "Operations": [
    {
      "op": "replace",
      "path": "urn:ietf:params:scim:schemas:extension:genesys:purecloud:2.0:User:externalIds",
      "value": [
        {
          "authority": "'$eid_auth'",
          "value": "'$eid_value'"
        }
      ]
    }
  ]
}'

echo "  JSON prepared: $update_data"
if [[ $drill_mode -eq 0 ]]; then
	response=$(echo "$update_data" | gc -p "$gc_profile" scim users update "$user_id" 2>&1 | jq -r 'if .status > 202 then "\(.status), \(.detail), \(.schemas)" else ."urn:ietf:params:scim:schemas:extension:genesys:purecloud:2.0:User".externalIds[0].value end')
	if [[ "$response" == "$eid_value" ]]; then
		echo "  update executed: success, response: $response"
		exit_code=0
	else
		echo -e "  update executed: failure, response: $response"
		exit_code=1
	fi
fi
exit $exit_code
