require 'rubygems/package'
require 'zlib'

desc "downloads MaxMind's GeoLite2-City database"
task "maxminddb:get" do

  def download_mmdb(name)
    puts "Downloading MaxMindDb #{name}"
    uri = URI("http://geolite.maxmind.com/download/geoip/database/#{name}.tar.gz")
    tar_gz_archive = Net::HTTP.get(uri)

    extractor = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tar_gz_archive)))
    extractor.rewind

    extractor.each do |entry|
      next unless entry.full_name.ends_with?(".mmdb")

      filename = File.join(Rails.root, 'vendor', 'data', "#{name}.mmdb")
      puts "Writing #{filename}..."
      File.open(filename, "wb") do |f|
        f.write(entry.read)
      end
    end

    extractor.close
  end

  download_mmdb('GeoLite2-City')
  download_mmdb('GeoLite2-ASN')
end
