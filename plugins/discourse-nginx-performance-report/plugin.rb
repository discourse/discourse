# name: discourse-nginx-performance-report
# about: Analyzing Discourse Performance using NGINX logs
# version: 0.1
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-nginx-performance-report

enabled_site_setting :daily_performance_report
enabled_site_setting_filter "daily_performance_report"
hide_plugin if self.respond_to?(:hide_plugin)

after_initialize do
  load File.expand_path("../app/jobs/scheduled/daily_performance_report.rb", __FILE__)
end
