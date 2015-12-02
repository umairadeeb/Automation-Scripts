#!/bin/bash
# This will print teamcity agents' name, ip, and/or host based on your input. If no argument is provided, the script will print all three.
# Dependency: xmllint, curl
#
# Written by: Umair A. Shahid

TCServer="teamcity.yourdomain.com"
TCPort="8111"


read -p "Username: " TCUSER
read -s -p "Password: " PASSWD

echo
echo
curl -s --user $TCUSER:$PASSWD http://$TCServer:$TCPort/httpAuth/app/rest/agents?includeDisconnected=true > /tmp/agentList.xml
echo "cat /agents-ref/agent/@id" | xmllint --shell /tmp/agentList.xml | grep "id=" | sed -e 's#id=##g' -e 's/"//g' > /tmp/agentList.txt

for agent in $(cat /tmp/agentList.txt); do
        curl -s --user $TCUSER:$PASSWD http://$TCServer:$TCPort/httpAuth/app/rest/agents/id:$agent > /tmp/TcAgent$agent.xml

        AgentName=$(curl -s --user $TCUSER:$PASSWD http://$TCServer:$TCPort/httpAuth/app/rest/agents/id:$agent/name)
        AgentIP=$(curl -s --user $TCUSER:$PASSWD http://$TCServer:$TCPort/httpAuth/app/rest/agents/id:$agent/ip)
        AgentHostname=$(echo "cat /agent/properties/property/@*" | xmllint --shell /tmp/TcAgent$agent.xml | grep "env.HOSTNAME" --after-context=2 | sed -e '$!d' -e 's#^.*.value=##g' -e 's#"##g')

        if [[ -z $1 ]]; then
        echo "$AgentName,$AgentIP,$AgentHostname"
else
        case "$1" in
                name )
                        echo "$AgentName" ;;
                ip )
                        echo "$AgentIP" ;;
                host )
                        echo "$AgentHostname" ;;
                * )
                        echo "Usage: $0 [name|ip|host]"
                        exit 1  ;;
        esac
fi

        rm -f /tmp/TcAgent$agent.xml
done
