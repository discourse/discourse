#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "json"

workflow_run_id = ARGV[0]
run_attempt = ARGV[1]
job_name = ARGV[2]

uri =
  URI.parse(
    "https://api.github.com/repos/discourse/discourse/actions/runs/#{workflow_run_id}/attempts/#{run_attempt}/jobs",
  )

request = Net::HTTP::Get.new(uri)
request["Accept"] = "application/vnd.github+json"
request["X-Github-Api-Version"] = "2022-11-28"

response =
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
    http.request(request)
  end

JSON.parse(response.body)["jobs"].each do |job|
  if job["name"] == job_name
    puts job["id"]
    break
  end
end
