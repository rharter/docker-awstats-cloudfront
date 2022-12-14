#!/usr/bin/with-contenv sh

export AWS_SHARED_CREDENTIALS_FILE=/config/.aws/credentials
export AWS_CONFIG_FILE=/config/.aws/config

echo "INFO: Starting sync.sh PID $$ $(date)"

if [ -z "$BUCKET" ]; then
  echo "ERROR: Missing BUCKET environment variable."
  exit 1
fi

if [ -n "$HEALTHCHECK_ID" ]; then
  curl -sS -X POST -o /dev/null "https://hc-ping.com/$HEALTHCHECK_ID/start"
fi

# sync the log bucket
echo "INFO: Syncing from bucket s3://${BUCKET}"
aws s3 sync s3://${BUCKET} /logs

echo "INFO: Combining log files..."
rm -f /tmp/combined.log
for f in /logs/*.gz
do
  zcat "$f" | grep -v "^#" | awk 'BEGIN{FS="\t"; OFS="\t" } { print $1 " " $2, $4, $5, $6, $8, $9, $10, $11 }' >> /tmp/combined.log; 
done

echo "INFO: Generating analytics html from combined log file."
eval awstats_buildstaticpages.pl -config=site -update -dir=/output/ ${AWSTATS_ARGS}

output_prefix=${HTML_FILENAME:-index}
echo "INFO: Renaming generated html file to ${output_prefix}.html."
mv /output/awstats.site.html "/output/${output_prefix}.html"

case "$POST_ACTION" in
  "" )
    ;;

  * )
    if [ -f "./${POST_ACTION}" ] && [ -x "./${POST_ACTION}" ]; then
      echo "INFO: Executing post action script: ./${POST_ACTION}"
      sh -c "./${POST_ACTION} /config/html/${output_prefix}.html"
    elif [ -f "/config/${POST_ACTION}" ] && [ -x "/config/${POST_ACTION}" ]; then
      echo "INFO: Executing post action script: /config/${POST_ACTION}"
      sh -c "/config/${POST_ACTION} /config/html/${output_prefix}.html"
    else
      echo "INFO: Executing post action: ${POST_ACTION}"
      eval "${POST_ACTION}"
    fi
    ;;

esac

if [ -n "$PRUNE" ];then
  delete_cmd="Objects=["
  log_count=0
  for f in $(find /logs/ -mtime +"${PRUNE}" ! -name 'combined.log.gz' -name '*.gz' -type f);do
    if [ ${log_count} -ne 0 ];then
      delete_cmd="${delete_cmd},"
    fi
    
    delete_cmd="${delete_cmd}{Key=${f#/logs/}}"

    let log_count++
  done
  delete_cmd="${delete_cmd}],Quiet=false"
  
  if [ $log_count -gt 0 ];then
    echo "INFO: Pruning ${log_count} old logs."

    # aws s3api desperately wants to open the results in less, which is shitty for scripting,
    # so we'll just write it to a file and cat that.
    aws s3api delete-objects --bucket ${BUCKET} --delete $delete_cmd > /tmp/delete_result.json
    cat /tmp/delete_result.json
  else
    echo "INFO: No log files match age ${PRUNE}, nothing to prune."
  fi
fi

echo "INFO: Completed sync.sh PID $$ $(date)"

if [ -n "$HEALTHCHECK_ID" ]; then
  curl -sS -X POST -o /dev/null --fail "https://hc-ping.com/$HEALTHCHECK_ID"
fi
