#!/bin/bash
# Usage: GITHUB_PAT=<token> ./poll_actions.sh
: "${GITHUB_PAT:?set GITHUB_PAT in the environment (never hard-code tokens)}"
REPO="RD7890/Ryzix2048-Watch"
while true; do
  RES=$(curl -s -H "Authorization: token $GITHUB_PAT" https://api.github.com/repos/$REPO/actions/runs?per_page=1)
  STATUS=$(echo "$RES" | grep -o '"status": "[^"]*"' | head -1 | cut -d'"' -f4)
  CONCLUSION=$(echo "$RES" | grep -o '"conclusion": "[^"]*"' | head -1 | cut -d'"' -f4)
  if [ "$STATUS" == "completed" ]; then
    echo "Build completed with conclusion: $CONCLUSION"
    echo "$RES" | grep -o '"html_url": "[^"]*"' | head -1
    exit 0
  else
    echo "Status: $STATUS (waiting...)"
    sleep 10
  fi
done
