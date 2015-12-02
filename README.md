# Automation-Scripts
This repo contain my scripts I wrote over the years to automate my tasks etc.

So far, these scripts are available to use:

#### AutoTempo.sh
- This script will import your timesheets' worklog to JIRA's TEMPO, taking input from another file.
- Works on Jira version 6.2.6 and Tempo Timesheets version 7.9.1.3

#### TC-AgentList.sh
- This script will print teamcity agents' name, ip, and/or host based on your input. If no argument is provided, the script will print all three.
- Simply execute ./TC-AgentList.sh <ip> / <host> / <name> or leave blank to print all three.
- Works perfectly on teamcity version 8.0.4 (build 27616)

#### TerminateInstances.sh
- This script will terminate all AWS EC2 instances if they are running for more than 24 hours and send a notification email. You can use below command for setting up cronjob.
- Example cron: 00 00 * * * root /path/to/TerminateAWSInstances_awscli.sh &>> /path/to/TerminateAWSInstances_awscli.log
