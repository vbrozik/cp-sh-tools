#!/bin/bash

# prometheus_info_collector.sh

# The tool collects information about data in a Prometheus database and saves it to JSON files.
# The data are saved in a directory named with the current date and hour: 2023-08-15_14_queries.
# The saved files are:
# - all_metrics.json: list of all metrics in the database
# - all_labels.json: list of all labels in the database
# - all_labels_with_value.json: list of all labels with their latest values in the database
# - all_labels_with_values_1h_unformatted.json:
#          list of all labels with their values in the last 1 hour (unformatted)

# The script can be sourced with the --source option
# to define the variables and pic_call_api function.

# parameters:

# base url for the Prometheus API points line query, series, label...
pic_api_base_url='https://127.0.0.1:9090/api/v1/'
# name of the directory to be created to save the collected data
pic_dirname="$(date +%F_%H)_queries"
# curl options for the Prometheus API calls
pic_curl_options=-nk
# curl command to be used for the Prometheus API calls
pic_curl_command=curl_cli

# Call the prometheus API and get the output.
# $1: API point to call with optional rest of the URL (e.g., series, query, label/__name__/values)
# $2: optional data to be sent with the API call (e.g., query={__name__!=""})
pic_call_api () {
    local api=$1
    local data=$2
    local url=$pic_api_base_url$api
    if test -n "$data" ; then
        "$pic_curl_command" $pic_curl_options "$url" --data-urlencode "$data"
    else
        "$pic_curl_command" $pic_curl_options "$url"
    fi
}

if test "$1" = --source ; then
  return 0
fi

{ mkdir "$pic_dirname" && cd "$pic_dirname" ; } || { printf %s\\n 'Failed creating dir.' ; exit 1 ; }

pic_call_api label/__name__/values > all_metrics.json
pic_call_api series 'match[]={name!=""}' > all_labels.json
pic_call_api query 'query={__name__!=""}' > all_labels_with_value.json
pic_call_api query 'query={__name__!=""}[1h]' > all_labels_with_values_1h_unformatted.json
