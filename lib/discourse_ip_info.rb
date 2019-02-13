# frozen_string_literal: true

require 'maxminddb'
require 'resolv'
require 'rubygems/package'
require 'zlib'

class DiscourseIpInfo
  include Singleton

  def initialize
    reload
  end

  def reload(path = nil)
    path ||= File.join(Rails.root, 'vendor', 'data')
    @loc_mmdb = load_mmdb(File.join(path, 'GeoLite2-City.mmdb'))
    @asn_mmdb = load_mmdb(File.join(path, 'GeoLite2-ASN.mmdb'))
    @cache = LruRedux::ThreadSafeCache.new(2000)
  end

  def self.reload(path = nil)
    instance.reload(path)
  end

  def load_mmdb(filepath)
    begin
      MaxMindDB.new(filepath, MaxMindDB::LOW_MEMORY_FILE_READER)
    rescue Errno::ENOENT => e
      Rails.logger.warn("MaxMindDB (#{filepath}) could not be found: #{e}")
      nil
    rescue => e
      Discourse.warn_exception(e, "MaxMindDB (#{filepath}) could not be loaded.")
      nil
    end
  end

  def lookup(ip, locale: :en, resolve_hostname: false)
    ret = {}
    return ret if ip.blank?

    if @loc_mmdb
      begin
        result = @loc_mmdb.lookup(ip)
        if result&.found?
          ret[:country] = result.country.name(locale) || result.country.name
          ret[:country_code] = result.country.iso_code
          ret[:region] = result.subdivisions.most_specific.name(locale) || result.subdivisions.most_specific.name
          ret[:city] = result.city.name(locale) || result.city.name
          ret[:latitude] = result.location.latitude
          ret[:longitude] = result.location.longitude
          ret[:location] = ret.values_at(:city, :region, :country).reject(&:blank?).uniq.join(", ")
        end
      rescue => e
        Discourse.warn_exception(e, message: "IP #{ip} could not be looked up in MaxMind GeoLite2-City database.")
      end
    end

    if @asn_mmdb
      begin
        result = @asn_mmdb.lookup(ip)
        if result&.found?
          result = result.to_hash
          ret[:asn] = result["autonomous_system_number"]
          ret[:organization] = result["autonomous_system_organization"]
        end
      rescue => e
        Discourse.warn_exception(e, message: "IP #{ip} could not be looked up in MaxMind GeoLite2-ASN database.")
      end
    end

    # this can block for quite a while
    # only use it explicitly when needed
    if resolve_hostname
      begin
        result = Resolv::DNS.new.getname(ip)
        ret[:hostname] = result&.to_s
      rescue Resolv::ResolvError
      end
    end

    ret
  end

  def get(ip, locale: :en, resolve_hostname: false)
    ip = ip.to_s
    locale = locale.to_s.sub('_', '-')

    @cache["#{ip}-#{locale}-#{resolve_hostname}"] ||=
      lookup(ip, locale: locale, resolve_hostname: resolve_hostname)
  end

  def self.get(ip, locale: :en, resolve_hostname: false)
    instance.get(ip, locale: locale, resolve_hostname: resolve_hostname)
  end

  def self.download_mmdb(name)
    uri = URI("http://geolite.maxmind.com/download/geoip/database/#{name}.tar.gz")
    tar_gz_archive = Net::HTTP.get(uri)

    extractor = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tar_gz_archive)))
    extractor.rewind

    extractor.each do |entry|
      next unless entry.full_name.ends_with?(".mmdb")

      filename = File.join(Rails.root, 'vendor', 'data', "#{name}.mmdb")
      File.open(filename, "wb") { |f| f.write(entry.read) }
    end

    extractor.close
  end

  def self.update!
    download_mmdb('GeoLite2-City')
    download_mmdb('GeoLite2-ASN')
  end
end
