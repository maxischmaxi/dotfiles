#!/bin/bash

diff=$(git diff --cached)
message="Please summarize the following changes in a commit message:\n\n$diff"
json=$(jq -n --arg msg "$message" '{"instructions": "keep your answers short, explain as well as possible what happens in these code changes. never ever add markdown, answer only with the commit message!", "model": "gpt-4.1", "input": $msg}')

response=$(curl -s https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json")

message=$(echo "$response" | jq -r '.output[0].content[0].text')

git commit -m "$message"
