#!/bin/bash

FAILED=0

echo -ne "mdspell "
mdspell --version
echo -ne "mdl "
mdl --version

# This performs spell checking and style checking over markdown files in a content
# directory. 
check_content() {
    DIR=$1
    LANG=$2

    mdspell ${LANG} --ignore-acronyms --ignore-numbers --no-suggestions --report *.md */*.md */*/*.md */*/*/*.md
    if [[ "$?" != "0" ]]
    then
        FAILED=1
    fi

    mdl --ignore-front-matter --style mdl_style.rb .
    if [[ "$?" != "0" ]]
    then
        FAILED=1
    fi
}

check_content . --en-us

if [[ ${FAILED} -eq 1 ]]
then
    echo "LINTING FAILED"
    exit 1
fi