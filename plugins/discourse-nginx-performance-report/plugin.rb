# name: discourse-nginx-performance-report
# about: Analyzing Discourse Performance using NGINX logs
# version: 0.1
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-nginx-performance-report

after_initialize do
  load File.expand_path("../app/jobs/scheduled/daily_performance_report.rb", __FILE__)
end
