#!/bin/bash

defaultPrettyFomat='%Cgreen%h %Creset• %s %Cred(%cN, %ar)%Creset'

function change_count() {
	git shortlog -sne --no-merges --since="$1"
}

function show_commit() {
	git show --numstat --pretty=format:"$defaultPrettyFomat" $1
}

function show_tags() {
	git log --no-walk --tags --format=format:"$defaultPrettyFomat"
}

# get path
function follow_file() {
	if [ ! -z "$1" ]; then
		git log --format=format:"$defaultPrettyFomat" --no-merges --follow "$1"
	else
		echo 'Path is required'
	fi
}

function history_commit_specific_day() {
	pattern_date='\(1[1-9]\{1\}\)-\([0-9]\{1,2\}\)-\([0-9]\{1,2\}\)'

	if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
		git log --after="20$1 00:00" --before="20$1 23:59" --format=format:"$defaultPrettyFomat" --no-merges
	else
		echo 'invalid date (YY-MM-DD)'
	fi
}

function show_graph() {
	# Check if limit is defined
	if [ ! -z "$1" ]; then
		git log --graph --branches --remotes --tags  --format=format:"$defaultPrettyFomat" --date-order -"$1"
	else
		git log --graph --branches --remotes --tags  --format=format:"$defaultPrettyFomat" --date-order -10
	fi

}

function history_commit() {
	if [ $# -eq 2 ]; then
		git log --format=format:"$defaultPrettyFomat" --no-merges --since="$1" --author=$2
	else
		git log --numstat --pretty=format:"$defaultPrettyFomat" --since="$1" --no-merges
	fi
}

function stats_modify_change() {
	readarray -t array_emails < <(change_count $1 | grep -E -o '\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b');

	for f in ${array_emails[@]}; do git log --shortstat --author=$f --since="$1" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END {print "files changed: " files " \t\tlines inserted: ", inserted" \t\tlines deleted: ", deleted" \t\t<'$f'>"}'; done;
}

function replace_ours_theirs_code() {
	git checkout --$1 $@ && git add $@;
}

function files_changes() {
	if [ $# -eq 2 ]; then
		git log --numstat --pretty=format:"$defaultPrettyFomat" --since="$1" --no-merges --author=$2
	else
		git log --numstat --pretty=format:"$defaultPrettyFomat" --since="$1" --no-merges
	fi
}

case "$1" in
1) stats_modify_change $2 ;;
2) change_count $2 ;;
3) replace_ours_theirs_code $2 ;;
4) files_changes $2 $3;;
5) history_commit $2 $3;;
6) show_commit $2;;
7) show_tags;;
8) show_graph $2;;
9) history_commit_specific_day $2;;
10) follow_file $2;;
esac
