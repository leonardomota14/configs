#!/bin/bash

defaultPrettyFomat='%Cgreen%h %Creset%C(red)•%Creset %s (%C(bold blue) %cN %Creset, %C(yellow) %ar %Creset )'
pattern_date='\([0-9]\{3\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)'

function stats_modify_change() {
	readarray -t array_emails < <(change_count $1 | grep -E -o '\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b');

	for f in ${array_emails[@]}; do git log --shortstat --author=$f --since="$1" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END {print "files changed: " files " \t\tlines inserted: ", inserted" \t\tlines deleted: ", deleted" \t\t<'$f'>"}'; done;
}

function change_count() {
	git shortlog -sne --no-merges --since="$1"
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

function history_commit() {
	if [ $# -eq 2 ]; then
		git log --format=format:"$defaultPrettyFomat" --no-merges --since="$1" --author=$2
	else
		git log --format=format:"$defaultPrettyFomat" --no-merges --since="$1"
	fi
}

function show_commit() {
	git show --numstat --pretty=format:"$defaultPrettyFomat" $1
}

function show_tags() {
	git log --no-walk --tags --format=format:"$defaultPrettyFomat"
}

function show_graph() {
	# Check if limit is defined
	if [ ! -z "$1" ]; then
		git log --graph --branches --remotes --tags  --format=format:"$defaultPrettyFomat" --date-order -"$1"
	else
		git log --graph --branches --remotes --tags  --format=format:"$defaultPrettyFomat" --date-order -10
	fi

}

function history_commit_specific_day() {
	if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
		git log --after="20$1 00:00" --before="20$1 23:59" --format=format:"$defaultPrettyFomat" --no-merges
	else
		echo 'invalid date (YYYY-MM-DD)'
	fi
}

function follow_file() {
	if [ ! -z "$1" ]; then
		git log --format=format:"$defaultPrettyFomat" --no-merges --follow "$1"
	else
		echo 'Path is required'
	fi
}

function winner() {
	if [ -n "$1" ]; then
		if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
			DATE=$1
		else
			echo 'invalid date (YYYY-MM-DD)'
			exit
		fi
	else
	  DATE=17-02-01
	fi

	PLAYERS=$(git shortlog --all --after=$DATE | grep '^\w' | sed 's/\(.*\) ([0-9]*):/\1/')

	HIGHEST_COMMIT_COUNT=0
	HIGHEST_COMMIT_LINES=0

	echo "Activity after $DATE"
	echo ""

	if [ -z "$PLAYERS" ]; then
	  echo "No players!"
	  echo ""
	  echo "Appears there have been no commits after $DATE.  Try an earlier date."
	  exit
	fi

	IFS='
	'

	for player in $PLAYERS; do
	  COMMIT_COUNT=$(git shortlog --all --after=$DATE --author="$player" | grep ^"$player (" | sed "s/$player (\(.*\)):/\1/")
	  COMMIT_LINES=$(git log      --all --after=$DATE --author="$player" --pretty=format: --stat | grep '[0-9]* files changed, [0-9]* insertions.*, [0-9]* deletions' | awk '{ sum += $4 + $6} END { print sum }')

	  if [ -z "$COMMIT_COUNT" ]; then
	    COMMIT_COUNT=0
	  fi

	  if [ -z "$COMMIT_LINES" ]; then
	    COMMIT_LINES=0
	  fi

	  if [ "$COMMIT_COUNT" -gt "$HIGHEST_COMMIT_COUNT" ]; then
	    HIGHEST_COMMIT_COUNT=$COMMIT_COUNT
	    HIGHEST_COMMIT_COUNT_PLAYER=$player
	  fi

	  if [ "$COMMIT_LINES" -gt "$HIGHEST_COMMIT_LINES" ]; then
	    HIGHEST_COMMIT_LINES=$COMMIT_LINES
	    HIGHEST_COMMIT_LINES_PLAYER=$player
	  fi

	  echo "Results for $player:"
	  echo "  # of commits        : $COMMIT_COUNT"
	  echo "  # of lines committed: $COMMIT_LINES"
	  echo "====================================="
	done

	if [ "$HIGHEST_COMMIT_COUNT" -gt 0 ]; then
	  echo ""
	  echo "$HIGHEST_COMMIT_COUNT_PLAYER wins in commit count with $HIGHEST_COMMIT_COUNT commits!"
	  echo "$HIGHEST_COMMIT_LINES_PLAYER wins in number of lines commited with $HIGHEST_COMMIT_LINES lines!"

	  if [ "$HIGHEST_COMMIT_COUNT_PLAYER" = "$HIGHEST_COMMIT_LINES_PLAYER" ]; then
	    FIRST_NAME=$(echo "$HIGHEST_COMMIT_COUNT_PLAYER" | awk '{ print $1 }')

	    echo ""
	    echo "$FIRST_NAME is the overall winner!!"
	  fi
	fi
}

function offten_files_today() {
	git log -M -C --name-only --since="midnight" --format='format:' "$@" | sort | grep -v '^$' | uniq -c | sort -n | awk 'BEGIN {print "count\tfile"} {print $1 "\t" $2}'
}

function offten_files_week() {
	git log -M -C --name-only --since="1 week ago" --format='format:' "$@" | sort | grep -v '^$' | uniq -c | sort -n | awk 'BEGIN {print "count\tfile"} {print $1 "\t" $2}'
}

function offten_files_month() {
	git log -M -C --name-only --since="last month" --format='format:' "$@" | sort | grep -v '^$' | uniq -c | sort -n | awk 'BEGIN {print "count\tfile"} {print $1 "\t" $2}'
}

function summary_line() {
	project=${PWD##*/}

	echo
	echo " project  : $project"
	echo " lines    : $(count)"
	echo " authors  :"
	result
	echo
}

# list the last modified author for each line
function single_file() {
  while read data
  do
    if [[ $(file "$data") = *text* ]]; then
      git blame --line-porcelain "$data" 2>/dev/null | grep "^author\ " | LC_ALL=C sed -n 's/^author //p';
    fi
  done
}

# list the author for all file
function lines() {
  git ls-files | single_file
}

# count the line count
function count() {
  lines | wc -l
}

# sort by author modified lines
function authors() {
  lines | sort | uniq -c | sort -rn
}

# list as percentage for author modified lines
function result() {
  authors | awk '
    { args[NR] = $0; sum += $0 }
    END {
      for (i = 1; i <= NR; ++i) {
        printf " %s, %2.1f%%\n", args[i], 100 * args[i] / sum
      }
    }
    ' | column -t -s,
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
11) winner $2;;
12) offten_files_today;;
13) offten_files_week;;
14) offten_files_month;;
15) summary_line;;
esac
