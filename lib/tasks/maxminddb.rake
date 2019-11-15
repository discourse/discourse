# frozen_string_literal: true

desc "downloads MaxMind's GeoLite2-City database"
task "maxminddb:get" do
  require 'discourse_ip_info'

  puts "Downloading MaxMindDb's GeoLite2-City..."
  DiscourseIpInfo.mmdb_download('GeoLite2-City')

  puts "Downloading MaxMindDb's GeoLite2-ASN..."
  DiscourseIpInfo.mmdb_download('GeoLite2-ASN')
end
