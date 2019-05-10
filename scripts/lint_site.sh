#!/bin/bash

FAILED=0

echo -ne "mdspell "
mdspell --version
echo -ne "mdl "
mdl --version

# This performs spell checking and style checking over changed markdown files
check_pull_request_content() {

	# only check pull request, skip others
	if [[ -z $CIRCLE_PULL_REQUEST ]]; then
		echo "Skip, only check pull request."
		exit 0
	fi

	# parse target/local branch
	CIRCLE_PR_NUMBER=${CIRCLE_PULL_REQUEST##*/}
	echo "PR number: $CIRCLE_PR_NUMBER"
	URL="https://api.github.com/repos/servicemesher/trans/pulls/$CIRCLE_PR_NUMBER"
	TARGET_BRANCH=$(curl -s -X GET -G $URL | jq '.base.ref' | tr -d '"')
	LOCAL_BRANCH=$(curl -s -X GET -G $URL | jq '.head.ref' | tr -d '"')

	# get changed files of this PR
	git checkout -q -b $LOCAL_BRANCH
	git checkout -q $TARGET_BRANCH
	git reset --hard -q origin/$TARGET_BRANCH
	git checkout -q $LOCAL_BRANCH

	echo "Getting list of changed markdown files ..."
	TOTAL_CHANGED_FILES=( $(git diff --name-only $TARGET_BRANCH..$LOCAL_BRANCH) )
	echo "Total changed files: ${#TOTAL_CHANGED_FILES[@]}"
	CHANGED_MARKDOWN_FILES=( $(git diff --name-only $TARGET_BRANCH..$LOCAL_BRANCH -- '*.md') )
	echo ${CHANGED_MARKDOWN_FILES[@]}

	if [[ "${#CHANGED_MARKDOWN_FILES[@]}" != "0" ]]; then
		echo "Check spell ..."
		mdspell --en-us --ignore-acronyms --ignore-numbers --no-suggestions --report ${CHANGED_MARKDOWN_FILES[@]}
		if [[ "$?" != "0" ]]; then
			echo "Spell check failed."
			echo "Feel free to add the word(s) into our glossary file '.spelling'."
			# set spell check as a weak check for now
			# FAILED=1
		fi

		echo "Check style ..."
		mdl --ignore-front-matter --style mdl_style.rb ${CHANGED_MARKDOWN_FILES[@]}
		if [[ "$?" != "0" ]]; then
			FAILED=1
		fi
	else
		echo "No changed markdown files to check."
	fi
}

check_pull_request_content

if [[ $FAILED -eq 1 ]]; then
	echo "LINTING FAILED"
	exit 1
else
	echo "LINTING SUCCEEDED"
fi
