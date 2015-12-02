#!/bin/bash
# This will import your timesheets' worklog to JIRA's TEMPO, taking input from another file.
# 
# Written by: Umair A. Shahid

### MODIFY THIS TO YOUR JIRA SERVER URL ###
jiraServer=jira.exampledomain.com

if [[ $# != 1 ]]; then
  echo "[FORMAT]: $0 /path/to/worklogs"
  echo "Worklogs must be formatted as below:"
  echo "(jira ticket)ABC-1234;(date)12/Jun/2015;(time)5h 30m;(comment)your comment should not include semicolon, percentage, and other special characters."
  echo
  exit 1
fi


jiraFile=$1

read -p "Username: " jiraUser
read -s -p "Password: " jiraPass

if [[ "$jiraUser" == "" || "$jiraPass" == "" ]]; then
  echo  "[ERROR!]: User or password not provided."
  exit 1
fi


echo
echo


while read worklog; do

ticket=$(echo $worklog | cut -d \; -f 1)
date=$(echo $worklog | cut -d \; -f 2)
timeSpent=$(echo $worklog | cut -d \; -f 3)
comment=$(echo $worklog | cut -d \; -f 4)

echo "[Processing Entry]: $worklog";

curl -D- -u $jiraUser:$jiraPass -X POST --data "comment=$comment&date=$date&time=$timeSpent&user=$jiraUser" -k http://$jiraServer/jira/rest/tempo-rest/1.0/worklogs/$ticket &> /dev/null || echo "[ERROR!]: Failed to process this entry.";

echo

done < $jiraFile

echo
echo "Finished processing $jiraFile"
