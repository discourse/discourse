# frozen_string_literal: true

require_dependency 'discourse_ip_info'

desc "downloads MaxMind's GeoLite2-City database"
task "maxminddb:get" do
  puts "Downloading MaxMindDb's GeoLite2-City..."
  DiscourseIpInfo.mmdb_download('GeoLite2-City')

  puts "Downloading MaxMindDb's GeoLite2-ASN..."
  DiscourseIpInfo.mmdb_download('GeoLite2-ASN')
end
