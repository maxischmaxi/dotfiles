#!/bin/bash

diff=$(git diff --cached)

patterns=(
  "api[_-]?key.{0,10}['\"]?[A-Za-z0-9_\-]{16,}"
  "secret.{0,10}['\"]?[A-Za-z0-9_\-]{16,}"
  "token.{0,10}['\"]?[A-Za-z0-9_\-]{16,}"
  "authorization.{0,10}['\"]?(Bearer )?[A-Za-z0-9\-_\.=]{20,}"
  "access[_-]?token.{0,10}['\"]?[A-Za-z0-9\-_\.=]{20,}"
  "-----BEGIN [A-Z ]*PRIVATE KEY-----"
  # Typische API-Key Formate (heuristisch)
  "[A-Za-z0-9]{20,40}"                         # lange zufällige Tokens
  "AIza[0-9A-Za-z\-_]{35}"                     # Google API Key
  "sk_live_[0-9a-zA-Z]{24}"                    # Stripe Live Secret Key
  "ghp_[A-Za-z0-9]{36}"                        # GitHub Personal Access Token
  "ya29\.[0-9A-Za-z\-_]+"                      # Google OAuth Token
  "[0-9a-f]{32}"                               # 32-stelliger hex (z. B. MD5 oder API Keys)
  "eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}"  # JWT Token
)

# Prüfung
for pattern in "${patterns[@]}"; do
  if echo "$diff" | grep -iE "$pattern" >/dev/null; then
    echo "❌ Sicherheitswarnung: Verdächtiger Key oder Token im git diff gefunden (Pattern: $pattern)"
    exit 1
  fi
done

message="Please summarize the following changes in a commit message:\n\n$diff"
json=$(jq -n --arg msg "$message" '{"instructions": "keep your answers short, explain as well as possible what happens in these code changes. never ever add markdown, answer only with the commit message!", "model": "gpt-4.1", "input": $msg}')

response=$(curl -s https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$json")

message=$(echo "$response" | jq -r '.output[0].content[0].text')

git commit -m "$message"
