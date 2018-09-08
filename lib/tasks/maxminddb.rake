require 'rubygems/package'
require 'zlib'

desc "downloads MaxMind's GeoLite2-City database"
task "maxminddb:get" => :environment do
  uri = URI("http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz")
  tar_gz_archive = Net::HTTP.get(uri)

  extractor = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tar_gz_archive)))
  extractor.rewind

  extractor.each do |entry|
    next unless entry.full_name.ends_with?(".mmdb")

    filename = File.join(Rails.root, 'vendor', 'data', 'GeoLite2-City.mmdb')
    File.open(filename, "wb") do |f|
      f.write(entry.read)
    end
  end

  extractor.close
end
