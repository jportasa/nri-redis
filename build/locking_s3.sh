#!/bin/bash
set -e
#
#  This script implements the locking mechanism functions to not having concurrent jobs updating the S3 repos
#  (APT, YUM, ZYPP...), to avoid wrong repo metadata. It creates a lock for each repo type in DynamoDB.
#
#
function create_dynamo_table {
  # Setup DynamoDB table
  if [ -z ${DYNAMO_TABLE_NAME+x} ]; then
    echo "$DYNAMO_TABLE_NAME is unset"
    exit 1
  fi
  if aws dynamodb describe-table --table-name $DYNAMO_TABLE_NAME --region $AWS_DEFAULT_REGION >/dev/null 2>&1 ; then
    echo "===> Dynamodb lock table already exists, I don't create it"
  else
    echo "===> Dynamodb lock table doen't exist, I create it"
    aws dynamodb create-table \
            --region $AWS_DEFAULT_REGION \
            --table-name $DYNAMO_TABLE_NAME \
            --attribute-definitions AttributeName=lock-type,AttributeType=S \
            --key-schema AttributeName=lock-type,KeyType=HASH \
            --sse-specification Enabled=true \
            --provisioned-throughput ReadCapacityUnits=2,WriteCapacityUnits=1
    aws dynamodb wait table-exists --table-name $DYNAMO_TABLE_NAME --region $AWS_DEFAULT_REGION
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "prerelease-yum"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "prerelease-apt"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "prerelease-zypp"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "release-yum"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "release-apt"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
    aws dynamodb put-item \
        --table-name $DYNAMO_TABLE_NAME \
        --item '{"lock-type": {"S": "release-zypp"}, "locked": {"BOOL": false}, "repo": {"S": "-"}}'
  fi
}

function wait_and_lock {
  while true; do
    set +e # Error if dynamo condition-expression fails, so we avoid error
    aws dynamodb update-item \
    --table-name ${DYNAMO_TABLE_NAME} \
    --key "{\"lock-type\": {\"S\": \"${LOCK_REPO_TYPE}\"}}" \
    --update-expression "SET locked = :t,repo = :r" \
    --expression-attribute-values "{\":t\":{\"BOOL\":true},\":f\":{\"BOOL\":false},\":r\":{\"S\":\"${REPO_FULL_NAME}\"}}" \
    --condition-expression 'locked = :f' \
    --return-values ALL_NEW \
    > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      set -e
      break
    fi
    repo_that_locks=$(aws dynamodb get-item \
       --table-name ${DYNAMO_TABLE_NAME}  \
       --key "{ \"lock-type\": {\"S\": \"${LOCK_REPO_TYPE}\"} }" \
       --projection-expression "repo" \
      | jq -r '.Item.repo.S');
    echo "===> Wait 10 seconds to retry lock status, repo: ${repo_that_locks} is locking"
    sleep 10
  done
}

function release_lock {
  aws dynamodb put-item \
    --table-name $DYNAMO_TABLE_NAME \
    --item "{\"lock-type\": {\"S\": \"${LOCK_REPO_TYPE}\"}, \"locked\": {\"BOOL\": false}, \"repo\": {\"S\": \"-\"}}"
  echo "===> Release Lock in $LOCK_REPO_TYPE"
}
