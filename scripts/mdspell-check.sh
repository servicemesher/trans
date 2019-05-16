#!/bin/bash

echo -ne "mdspell "
mdspell --version

# This performs markdown spell check over changed markdown files
check_pull_request_content() {

	# only check pull request, skip others
	if [[ -z $CIRCLE_PULL_REQUEST ]]; then
		echo "Skip, only check pull request."
		exit 0
	fi

	# get changed files of this PR
	CIRCLE_PR_NUMBER=${CIRCLE_PULL_REQUEST##*/}
	OWNER=$(echo $CIRCLE_PULL_REQUEST | cut -d / -f 4)
	REPO=$(echo $CIRCLE_PULL_REQUEST | cut -d / -f 5)
	URL="https://api.github.com/repos/$OWNER/$REPO/pulls/$CIRCLE_PR_NUMBER/files"

	echo
	echo "Getting list of changed markdown files..."
	CHANGED_MARKDOWN_FILES=( $(curl -s -X GET -G $URL | jq -r '.[] | select(.status != "removed") | select(.filename | endswith(".md")) | .filename') )
	echo "Total changed markdown files: ${#CHANGED_MARKDOWN_FILES[@]}"
	echo ${CHANGED_MARKDOWN_FILES[@]}

	if [[ "${#CHANGED_MARKDOWN_FILES[@]}" != "0" ]]; then
		mdspell --en-us --ignore-acronyms --ignore-numbers --no-suggestions --report ${CHANGED_MARKDOWN_FILES[@]}
		if [[ "$?" != "0" ]]; then
			echo "[WARNING]: Spell check failed. Feel free to add the term(s) into our glossary file '.spelling'."
		fi
	else
		echo "No changed markdown files to check."
	fi
}

check_pull_request_content
