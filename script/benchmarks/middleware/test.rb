require 'memory_profiler'
require 'benchmark/ips'

ENV["RAILS_ENV"] = "production"

require File.expand_path("../../../../config/environment", __FILE__)

def req
  _t = "9c1a318cb72cca57daf413cc511f0993"

  data = {
    "timings[1]" => "1001",
    "timings[2]" => "1001",
    "timings[3]" => "1001",
    "topic_id" => "490310"
  }

  data = data.map do |k, v|
    "#{CGI.escape(k)}=#{v}"
  end.join("&")

  {
    "REQUEST_METHOD" => "POST",
    "SCRIPT_NAME" => "",
    "PATH_INFO" => "/topics/timings.json",
    "QUERY_STRING" => "",
    "SERVER_NAME" => "localhost",
    "SERVER_PORT" => "80",
    "HTTP_CONTENT_TYPE" => "application/x-www-form-urlencoded",
    "HTTP_VERSION" => "HTTP/1.0",
    "HTTP_COOKIE" => "_t=#{_t}",
    "rack.input" => StringIO.new(data),
    "rack.version" => [1, 2],
    "rack.url_scheme" => "http"
  }
end

1.times do
  s = Time.now
  Rails.application.call(req)
  puts(Time.now - s)
end
exit
#
#
StackProf.run(mode: :wall, out: 'report.dump') do
  1000.times do
    Rails.application.call(req)
  end
end
#
# MemoryProfiler.start
# Rails.application.call(req)
# MemoryProfiler.stop.pretty_print
# exit

# # exit
# exit

# Benchmark.ips do |x|
#   x.report("default") do
#     Rails.application.call(req)
#   end
# end

# status, headers, body = Rails.application.call(req)
# p status
# p headers
# body.each do |s|
#   p s.to_s
# end
