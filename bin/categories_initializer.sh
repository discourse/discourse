#!/bin/bash

do_usage() {
cat << EOT
Description:
  TBD

Options:
	TBD

Usage:
  $ ./bin/categories_initializer.sh -a {api key} -u {username} -f {file} -e {env}

Sample:
  $ ./bin/categories_initializer.sh -a abc123 -u charnel -f categories.csv -e local

Prerequisite:
	$ chmod u+x ./bin/categories_initializer.sh

EOT
	exit 1
}

do_error() {
	message=$1
	echo "$message"
	exit 1
}

read_csv() {
	"""
	Read the input CSV file.
	"""
	csv_records=()
	while IFS= read record
	do
		csv_records+=("$record")
	done < <(tail -n +2 files/$filename)
}

call_api() {
	"""
	Call the Discourse API.
	"""
	for record in "${csv_records[@]}"; 
	do
		IFS=','
		read -r name bg_color text_color parent_id  <<< "$record"
		echo "category name: $name"
		echo "category background color: $bg_color"
		echo "category text color: $text_color"
		echo "category parent id: $parent_id"
		echo ""
	done
}

while getopts a:u:e:f:h: flag 
do
	case $flag in
		a) api_key=${OPTARG};;
		u) username=${OPTARG};;
		e) env=${OPTARG};;
		f) filename=${OPTARG};;
		h) do_usage;;
		*) do_error "See $0 -h for options";;
	esac
done

read_csv
call_api