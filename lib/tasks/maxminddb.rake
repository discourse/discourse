require_dependency 'discourse_ip_info'

desc "downloads MaxMind's GeoLite2 database"
task "maxminddb:get" do
  DiscourseIpInfo.update!
end
