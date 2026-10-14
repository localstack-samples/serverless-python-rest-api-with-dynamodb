#!/bin/bash
# Walk a todo through the REST API: create, read, list, update, delete.
set -euo pipefail

STAGE=${STAGE:-local}
STACK=serverless-python-rest-api-with-dynamodb-$STAGE
TEXT="todo from CI $(date +%s)"

ENDPOINT=$(lstk aws cloudformation describe-stacks --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='ServiceEndpoint'].OutputValue" --output text)
TODOS="${ENDPOINT%/}/todos"
echo "API: $TODOS"

# Print the body, or fail with the status and body on a non-2xx response
request() {
  local body status
  body=$(curl -s -m 30 -w '\n%{http_code}' -H 'Content-Type: application/json' "$@")
  status=${body##*$'\n'}
  body=${body%$'\n'*}
  if [ "${status:0:1}" != "2" ]; then
    echo "Test failed: $* returned HTTP $status: $body" >&2
    return 1
  fi
  echo "$body"
}

created=$(request -X POST "$TODOS" -d "{\"text\": \"$TEXT\"}")
ID=$(echo "$created" | jq -r '.id')
if [ -z "$ID" ] || [ "$ID" = "null" ] || ! echo "$created" | jq -e '.checked == false' > /dev/null; then
  echo "Test failed: create returned $created"
  exit 1
fi
echo "PASS: created todo $ID"

todo=$(request "$TODOS/$ID")
if ! echo "$todo" | jq -e --arg t "$TEXT" '.text == $t' > /dev/null; then
  echo "Test failed: get returned $todo"
  exit 1
fi
echo "PASS: read todo back"

if ! request "$TODOS" | jq -e --arg id "$ID" 'any(.[]; .id == $id)' > /dev/null; then
  echo "Test failed: todo $ID missing from the list"
  exit 1
fi
echo "PASS: todo appears in the list"

updated=$(request -X PUT "$TODOS/$ID" -d '{"text": "updated by CI", "checked": true}')
if ! echo "$updated" | jq -e '.text == "updated by CI" and .checked == true' > /dev/null; then
  echo "Test failed: update returned $updated"
  exit 1
fi
echo "PASS: updated todo"

request -X DELETE "$TODOS/$ID" > /dev/null
if request "$TODOS" | jq -e --arg id "$ID" 'any(.[]; .id == $id)' > /dev/null; then
  echo "Test failed: todo $ID still listed after delete"
  exit 1
fi
echo "PASS: deleted todo"

echo "Test passed: todos API handled the full CRUD cycle"
