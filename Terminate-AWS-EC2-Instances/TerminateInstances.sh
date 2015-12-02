#!/bin/bash
# This will terminate all AWS EC2 instances if they are running for more than 24 hours and send a notification email. You can use below command for setting up cronjob.
# 00 00 * * * root /path/to/TerminateAWSInstances_awscli.sh &>> /path/to/TerminateAWSInstances_awscli.log
# DEPENDENCIES: awscli, jq, mutt
#
# Written by: Umair A. Shahid

##################################
#      AWS CLI PROPERTIES        #
##################################
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
REGION="us-east-1"
OUTPUT_FORMAT="json"
##################################


TEMP_FOLDER="/tmp"
EXCLUDE_LIST="/root/Instances.EXCLUDE" ####### THIS FILE SHOULD ONLY CONTAIN IP ADDRESSES OF INSTANCES SEPARATED BY LINE
EMAIL_CONTENT="$TEMP_FOLDER/Email.NOTIFICATION"
INFRA_INSTANCES=(192.168.1.1) ####### This should contain IPs of Infrastructure Instances which will not be terminated ever, separated by space. PLEASE DONT MODIFY IT IF YOU ARE NOT SURE WHAT YOU ARE DOING.
TERMINATION_LIST="$TEMP_FOLDER/.Instances.TERMINATE"
RECIPIENT_LIST="" ####### Email address on which the notification will be sent.
currentTime=`date -u +%F"T"%T`
currentTimeEpoch=`date --date=$currentTime "+%s"`
currentTimeStamp=`date +%Y%m%d%H%M%S`
AWS_OUTPUT="${TEMP_FOLDER}/.Instances_${REGION}_${currentTimeStamp}"


echo
echo "######### Executed at: $(date) ##########"
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "#######################################"
echo


if [[ ! -f $EXCLUDE_LIST ]]; then
  touch $EXCLUDE_LIST
fi

if [[ -f $TERMINATION_LIST ]]; then
  rm -f $TERMINATION_LIST
fi

if [[ -f $AWS_OUTPUT ]]; then
  rm -f $AWS_OUTPUT
fi

if [[ -f $EMAIL_CONTENT ]]; then
  rm -f $EMAIL_CONTENT
fi


echo '<html><head><style>.boldtable, .boldtable TD, .boldtable TH { font-family:"Courier New", Courier, monospace; font-size:9pt; color:black; }</style></head><body><font face="Courier New" size="-1">' > $EMAIL_CONTENT

echo "- Getting list of running instances."
echo "aws --region $REGION --output $OUTPUT_FORMAT ec2 describe-instances --filter Name=instance-state-name,Values=running,booting,pending,stopping,shutting-down >> $AWS_OUTPUT"
echo

aws --region $REGION --output $OUTPUT_FORMAT ec2 describe-instances --filter Name=instance-state-name,Values=running,booting,pending,stopping,shutting-down >> $AWS_OUTPUT

Number_Of_Running_Instances=`cat $AWS_OUTPUT | jq '.Reservations | length'`

echo  '<table border class="boldtable" border="1" cellpadding="5" cellspacing="0" bordercolor="gray"> <tr> <th>Instance IP</th> <th>Duration</th> <th>Instance Type</th> <th>Instance Tags</th> <th>Instance State</th> <th>Comment</th> </tr>' >> $EMAIL_CONTENT


for i in $(seq 0 `expr $Number_Of_Running_Instances - 1`);do

  IP=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .PrivateIpAddress' | sed "s/\"//g"`
  TYPE=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .InstanceType' | sed "s/\"//g"`
  TAG=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .Tags[] | .Value' 2>/dev/null`
  STATUS=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .State .Name' | sed "s/\"//g"`
  ID=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .InstanceId'  | sed "s/\"//g"`
  LAUNCHTIME=`cat $AWS_OUTPUT | jq '.Reservations['$i'] .Instances[0] .LaunchTime' | sed "s/Z//" | sed "s/\"//g"`
  launchTimeEpoch=`date --date=$LAUNCHTIME "+%s"`
  time_diff=`expr $currentTimeEpoch - $launchTimeEpoch`
  days=`expr $time_diff / 86400 | awk -F"." '{print $1}'`
  hours=`expr $time_diff % 86400 / 3600 | awk -F"." '{print $1}'`
  UPTIME="$days Days $hours Hours"


  echo "<tr>" >> $EMAIL_CONTENT
  echo "<td>$IP</td>" >> $EMAIL_CONTENT
  echo "<td>$UPTIME</td>" >> $EMAIL_CONTENT
  echo "<td>$TYPE</td>" >> $EMAIL_CONTENT
  echo "<td>$TAG</td>" >> $EMAIL_CONTENT
  echo "<td>$STATUS</td>" >> $EMAIL_CONTENT

  if [[ $days -ge 1 ]]; then

    if [[ "$(for ip in ${INFRA_INSTANCES[*]}; do echo $ip | egrep "^$IP$"; done)" == "$IP" ]]; then

      echo "- Infrastructure Instance: $IP ($ID)"
      echo "<td><font color="green">Infrastructure instance</font></td>" >> $EMAIL_CONTENT

    elif [[ "$(egrep "^$IP$" $EXCLUDE_LIST)" == "$IP" ]]; then

      echo "- Excluded Instance: $IP ($ID)"
      echo "<td><font color="green">Excluded instance</font></td>" >> $EMAIL_CONTENT

    else

      echo "- To be Terminated: $IP ($ID)"
      echo "<td><font color="red">Marked for termination</font></td>" >> $EMAIL_CONTENT
      echo "$ID,$IP" >> $TERMINATION_LIST
    fi

  fi

done

echo

echo "</tr>" >> $EMAIL_CONTENT
echo "</table> <br><br />" >> $EMAIL_CONTENT


#####################################
#       TERMINATE INSTANCES         #
#####################################

if [[ -f $TERMINATION_LIST ]] && [[ $(cat $TERMINATION_LIST | wc -l) -ge 1 ]]; then

  while read line; do
    id=`echo $line | awk -F',' '{print $1}'`
    ip=`echo $line | awk -F',' '{print $2}'`
    echo "- Terminating instance: $ip ($id) <br>" >> $EMAIL_CONTENT
    echo "aws --output $OUTPUT_FORMAT ec2 terminate-instances --instance-ids $id --region $REGION"
    aws --output $OUTPUT_FORMAT ec2 terminate-instances --instance-ids $id --region $REGION
  done < $TERMINATION_LIST

else
  echo "- Nothing to terminate. Exiting now! <br />" >> $EMAIL_CONTENT
fi


#####################################
#     END TERMINATE INSTANCES       #
#####################################


mutt -e "set content_type=text/html" -s "[TERMINATED] DEV/SIT EC2 Instances as of $(date)" $RECIPIENT_LIST < $EMAIL_CONTENT

rm -f $AWS_OUTPUT
