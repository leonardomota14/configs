#!/bin/bash

defaultPrettyFomat='%C(green)%h %C(reset)%C(red)•%C(reset) %s (%C(bold blue)%cN %C(reset), %C(yellow) %ar%C(reset))'
PrettyFomatGraph='%C(green)%h %C(bold yellow)-%C(reset)%C(bold red)%d%C(reset) %C(reset)%C(bold yellow)•%C(reset) %s (%C(bold blue)%cN %C(reset), %C(yellow) %ar%C(reset))'
pattern_date='\([0-9]\{3\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)'

function stats_modify_change() {
	readarray -t array_emails < <(change_count $1 | grep -E -o '\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b' | sort -fu);

	for f in ${array_emails[@]}; do git log --shortstat --author="$f" --since="$1" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END {print "files changed: " files " \t\tlines inserted: ", inserted" \t\tlines deleted: ", deleted" \t\t<'$f'>"}'; done;
}

function change_count() {
	git shortlog -sne --no-merges --since="$1" | sort -fu
}

function replace_ours_theirs_code() {
	git checkout --$1 $@ && git add $@;
}

function files_changes() {
	if [ $# -eq 2 ]; then
		git log --numstat --pretty=format:"$defaultPrettyFomat" --since="$1" --no-merges --author="$2"
	else
		git log --numstat --pretty=format:"$defaultPrettyFomat" --since="$1" --no-merges
	fi
}

function history_commit() {
	if [ $# -eq 2 ]; then
		git log --format=format:"$defaultPrettyFomat" --no-merges --since="$1" --author="$2"
	else
		git log --format=format:"$defaultPrettyFomat" --no-merges --since="$1"
	fi
}

function show_commit() {
	git show --numstat --pretty=format:"$defaultPrettyFomat" $1
}

function show_tags() {
	git log --no-walk --tags --format=format:"$PrettyFomatGraph"
}

function show_graph() {
	# Check if limit is defined
	if [ ! -z "$1" ]; then
		git log --graph --branches --remotes --tags  --format=format:"$PrettyFomatGraph" --date-order -"$1"
	else
		git log --graph --branches --remotes --tags  --format=format:"$PrettyFomatGraph" --date-order -10
	fi

}

function history_commit_specific_day() {
	if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
		if [ ! -z "$2" ]; then
			if date -d $(echo "$2" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
				git log --after="$1 00:00:00" --before="$2 23:59" --format=format:"$defaultPrettyFomat" --no-merges
			else
				echo 'invalid date (YYYY-MM-DD)'
			fi
		else
			git log --after="$1 00:00:00" --before="$1 23:59" --format=format:"$defaultPrettyFomat" --no-merges
		fi
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

function follow_file_displaying() {
	if [ ! -z "$1" ]; then
		git log -p --format=format:"$defaultPrettyFomat" --no-merges --follow --ignore-space-at-eol --ignore-blank-lines --remove-empty --ignore-all-space --ignore-space-change --log-size "$1"
	else
		echo 'Path is required'
	fi
}

function winner() {
	if [ $# -eq 2 ]; then
		if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
			DATE=$1
		else
			echo 'invalid date (YYYY-MM-DD)'
			exit
		fi
		if [ "$2" = "-d" ]; then
		  DETAIL=y
		fi
	fi
	if [ $# -eq 1 ]; then
		if [ "$1" = "-d" ]; then
		  DETAIL=y
		 else
		 	if date -d $(echo "$1" | sed -n "/$pattern_date/ { s/$pattern_date/\3-\2-\1/; p }") > /dev/null 2>&1 ; then
		 		DATE=$1
		 	else
		 		echo 'invalid date (YYYY-MM-DD)'
		 		exit
		 	fi
		fi
	fi
	if [ $# -eq 0 ]; then
		DATE=$(date +%m-%d-%Y) # Today
	fi

	PLAYERS=$(git shortlog -e --all --after="$DATE 00:00:00" | grep -E -o '\b[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\b' | sort -fu)

	HIGHEST_COMMIT_COUNT=0
	HIGHEST_FILES_COUNT=0
	HIGHEST_COMMIT_LINES_INSERTED=0
	HIGHEST_COMMIT_LINES_DELETED=0
	LOWEREST_COMMIT_COUNT=500
	LOWEREST_FILES_COUNT=500
	LOWEREST_COMMIT_LINES_INSERTED=500
	LOWEREST_COMMIT_LINES_DELETED=500

	echo "Activity after $DATE"
	echo ""

	if [ -z "$PLAYERS" ]; then
	  echo "No players!"
	  echo ""
	  echo "Appears there have been no commits after $DATE.  Try an earlier date."
	  exit
	fi


	for player in $PLAYERS; do

	  COMMIT_COUNT=$(git shortlog -sn --all --no-merges --after="$DATE 00:00:00" --author="$player" --pretty=format: --stat | grep '[0-9]*' | awk '{ sum += $1} END { print sum }')
	  FILES_COUNT=$(git log --shortstat --no-merges --after="$DATE  00:00:00" --author="$player" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END { print files}')
	  COMMIT_LINES_INSERTED=$(git log --shortstat --no-merges --after="$DATE  00:00:00" --author="$player" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END { print inserted}')
	  COMMIT_LINES_DELETED=$(git log --shortstat --no-merges --after="$DATE  00:00:00" --author="$player" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END { print deleted}')

	  if [ -z "$COMMIT_COUNT" ]; then
	    COMMIT_COUNT=0
	  fi

	  if [ -z "$FILES_COUNT" ]; then
	    FILES_COUNT=0
	  fi

	  if [ -z "$COMMIT_LINES_INSERTED" ]; then
	    COMMIT_LINES_INSERTED=0
	  fi

	  if [ -z "$COMMIT_LINES_DELETED" ]; then
	    COMMIT_LINES_DELETED=0
	  fi

	  if [ "$COMMIT_COUNT" -gt "$HIGHEST_COMMIT_COUNT" ]; then
	    HIGHEST_COMMIT_COUNT=$COMMIT_COUNT
	    HIGHEST_COMMIT_COUNT_PLAYER=$player
	  fi

	  if [ "$FILES_COUNT" -gt "$HIGHEST_FILES_COUNT" ]; then
	    HIGHEST_FILES_COUNT=$FILES_COUNT
	    HIGHEST_FILES_COUNT_PLAYER=$player
	  fi


	  if [ "$COMMIT_LINES_INSERTED" -gt "$HIGHEST_COMMIT_LINES_INSERTED" ]; then
	    HIGHEST_COMMIT_LINES_INSERTED=$COMMIT_LINES_INSERTED
	    HIGHEST_COMMIT_LINES_INSERTED_PLAYER=$player
	  fi

	  if [ "$COMMIT_LINES_DELETED" -gt "$HIGHEST_COMMIT_LINES_DELETED" ]; then
	    HIGHEST_COMMIT_LINES_DELETED=$COMMIT_LINES_DELETED
	    HIGHEST_COMMIT_LINES_DELETED_PLAYER=$player
	  fi

	  if [ "$COMMIT_COUNT" -lt "$LOWEREST_COMMIT_COUNT" ]; then
	    LOWEREST_COMMIT_COUNT=$COMMIT_COUNT
	    LOWEREST_COMMIT_COUNT_PLAYER=$player
	  fi

	  if [ "$FILES_COUNT" -lt "$LOWEREST_FILES_COUNT" ]; then
	    LOWEREST_FILES_COUNT=$FILES_COUNT
	    LOWEREST_FILES_COUNT_PLAYER=$player
	  fi


	  if [ "$COMMIT_LINES_INSERTED" -lt "$LOWEREST_COMMIT_LINES_INSERTED" ]; then
	    LOWEREST_COMMIT_LINES_INSERTED=$COMMIT_LINES_INSERTED
	    LOWEREST_COMMIT_LINES_INSERTED_PLAYER=$player
	  fi

	  if [ "$COMMIT_LINES_DELETED" -lt "$LOWEREST_COMMIT_LINES_DELETED" ]; then
	    LOWEREST_COMMIT_LINES_DELETED=$COMMIT_LINES_DELETED
	    LOWEREST_COMMIT_LINES_DELETED_PLAYER=$player
	  fi

	  echo "Results for $player:"
	  echo ""
	  echo "  # of commits         : $COMMIT_COUNT"
	  echo "  # of files changed   : $FILES_COUNT"
	  echo "  # of lines inserted  : $COMMIT_LINES_INSERTED"
	  echo "  # of lines deleted   : $COMMIT_LINES_DELETED"

	  if [ -n "$DETAIL" ]; then
			echo ""
			echo "Commit summary"
			echo ""
			git shortlog --no-merges --after="$DATE 00:00:00" --pretty=format:"$defaultPrettyFomat" --author="$player"
	  fi

	  echo "========================================================"
	done

  echo "Results for Wins:"
  echo ""
  echo "  # $HIGHEST_COMMIT_COUNT_PLAYER wins in commit count with $HIGHEST_COMMIT_COUNT"
  echo "  # $HIGHEST_FILES_COUNT_PLAYER wins in files count with $HIGHEST_FILES_COUNT"
  echo "  # $HIGHEST_COMMIT_LINES_INSERTED_PLAYER wins in inserted lines : $HIGHEST_COMMIT_LINES_INSERTED"
  echo "  # $HIGHEST_COMMIT_LINES_DELETED_PLAYER wins in deleted lines : $HIGHEST_COMMIT_LINES_DELETED"
  echo ""
  echo "Results for Losts:"
  echo ""
  echo "  # $LOWEREST_COMMIT_COUNT_PLAYER lost in commit count with $LOWEREST_COMMIT_COUNT"
  echo "  # $LOWEREST_FILES_COUNT_PLAYER lost in files count ith $LOWEREST_FILES_COUNT"
  echo "  # $LOWEREST_COMMIT_LINES_INSERTED_PLAYER lost in inserted lines with $LOWEREST_COMMIT_LINES_INSERTED"
  echo "  # $LOWEREST_COMMIT_LINES_DELETED_PLAYER lost in deleted lines with $LOWEREST_COMMIT_LINES_DELETED"
	echo "========================================================"
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

function check_new_updates() {
	git remote show origin | grep 'master   pushes to master   (local out of date)' &> /dev/null;
	if [ $? == 0 ]; then
	  notify-send -i gtk-dialog-info -u critical 'Git updates' 'There are updates available'
	else
	  notify-send -i gtk-dialog-info -u critical 'Git updates' 'No there are updates available'
	fi
}

#
# Name: Code Version
# Description: used to diff file in specif version
#
# Command:
# git cv commit_hash path/to/file
#
# Input:
#
# $1 {COMMIT_HAS} Hash Of Commit
# $2 {PATH_FILE} Location of File
#
# Output:
#
# VSCODE with diff files between version
#

function code_version() {
	if [ $# -eq 2 ]; then
		# git show "$1":"$2" | xclip -sel clip;
		git show "$1":"$2" > "$2".bkp 2>&1
		code -d "$2" "$2".bkp
		exit
	fi
	if [ $# -eq 1 ]; then
		echo 'Insert Path to File'
	else
		echo 'Insert COMMIT_SHA1 and Path to File'
		exit
	fi

}

function pull_plus() {
	git stash
	git pull
	git stash pop
}

case "$1" in
1) stats_modify_change "$2" ;;
2) change_count $2 ;;
3) replace_ours_theirs_code $2 ;;
4) files_changes "$2" $3;;
5) history_commit "$2" $3;;
6) show_commit $2;;
7) show_tags;;
8) show_graph $2;;
9) history_commit_specific_day $2 $3;;
10) follow_file $2;;
11) winner $2 $3;;
12) offten_files_today;;
13) offten_files_week;;
14) offten_files_month;;
15) summary_line;;
16) follow_file_displaying $2;;
17) check_new_updates;;
18) code_version $2 $3;;
19) pull_plus;;
esac
