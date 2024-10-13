#!/usr/bin/env bash
# regions.sh
# 
# (c) 2016-2021 Jason Maurer
# (c) 2024 William Anderson <neuro@geekha.us>

set -e ; source $(dirname $(readlink -f ${0}))/common.sh 2>/dev/null || ( echo "$(basename ${0}): failed to source common.sh" >&2 ; exit 1 ) ; set +e

exit_if_no_aws_credentials
check_commands_in_path aws jq unexpand

REGION_DATA_FILE=$(dirname $(readlink -f ${0}))/regions.json
REGION_TEMP_FILE=$(mktemp /var/tmp/r_regionsjson.XXXXXXXX)
# This needs all regions to be enabled in your AWS account to provide
# an accurate list of regions. You can verify this by visiting
# https://console.aws.amazon.com/iam/home#/account_settings
# or confirming this command does not output any region names
# aws account list-regions | jq -r '. | select(.Regions[].RegionOptStatus | contains("ENABLED") | not) | .Regions[].RegionName'
echo " * building aws region list"
cat << EOM > ${REGION_TEMP_FILE}
{
    "Regions": [
EOM
COUNTER=0
for AWS_REGION in $(aws ec2 describe-regions --all-regions | jq -r '.Regions[].RegionName' | sort)
do
    if [ "${AWS_REGION}" ]; then COUNTER=$((COUNTER+1)); fi
    echo -n " - ${AWS_REGION} "
    AWS_REGION_LONGNAME=${AWS_REGION}
    AWS_REGION_SHORTNAME=$(aws --output=json ssm get-parameters-by-path --path /aws/service/global-infrastructure/regions/${AWS_REGION}/availability-zones | jq -r '.Parameters[0].Value' | cut -d- -f1)
    echo -n "(${AWS_REGION_SHORTNAME}) "
    AWS_REGION_FULLNAME=$(aws --output=json ssm get-parameter --name /aws/service/global-infrastructure/regions/${AWS_REGION}/longName | jq -r '.Parameter.Value')
    echo -n "${AWS_REGION_FULLNAME}"
    AWS_REGION_DISPLAYNAME="$(echo ${AWS_REGION_FULLNAME} | cut -d\( -f2 | cut -d\) -f1)"
    AWS_REGION_AZS=$(aws --region=${AWS_REGION} --output=json ec2 describe-availability-zones | jq '.AvailabilityZones | map(.ZoneName)')
    echo " $(echo ${AWS_REGION_AZS} | jq '. | length') AZs"
    # aws --region=${AWS_REGION} --output=json ec2 describe-availability-zones | jq -r '.AvailabilityZones[] | .RegionName + "," + .ZoneId + "," + .ZoneName'
    # echo "${AWS_REGION_LONGNAME} (${AWS_REGION_SHORTNAME}) ${AWS_REGION_DISPLAYNAME}"
    if [ "${COUNTER}" -gt "1" ]; then echo "," >> ${REGION_TEMP_FILE}; fi
    cat << EOM >> ${REGION_TEMP_FILE}
{
    "RegionName": "${AWS_REGION_LONGNAME}",
    "RegionShortName": "${AWS_REGION_SHORTNAME}",
    "RegionDisplayName": "${AWS_REGION_DISPLAYNAME}",
    "RegionFullName": "${AWS_REGION_FULLNAME}",
    "AvailabilityZones": ${AWS_REGION_AZS}
}
EOM
done

cat << EOM >> ${REGION_TEMP_FILE}
] }
EOM

jq -r '.' ${REGION_TEMP_FILE} | unexpand -t2 > ${REGION_DATA_FILE}

exit 0 

cat > v2/data.go <<EOF
/**
 * This file is auto-generated from aws-regions/regions.sh
 */
package regions

const REGION_DATA string = \`$(cat regions.json)\`
EOF
