require_dependency 'maxminddb'

class DiscourseIpInfo
  include Singleton

  def initialize
    open_db(File.join(Rails.root, 'vendor', 'data'))
  end

  def open_db(path)
    begin
      @mmdb_filename = File.join(path, 'GeoLite2-City.mmdb')
      @mmdb = MaxMindDB.new(@mmdb_filename, MaxMindDB::LOW_MEMORY_FILE_READER)
      @cache = LruRedux::ThreadSafeCache.new(1000)
    rescue Errno::ENOENT => e
      Rails.logger.warn("MaxMindDB could not be found: #{e}")
    rescue
      Rails.logger.warn("MaxMindDB could not be loaded.")
    end
  end

  def lookup(ip, locale = :en)
    return {} unless @mmdb

    begin
      result = @mmdb.lookup(ip)
    rescue
      Rails.logger.error("IP #{ip} could not be looked up in MaxMindDB.")
    end

    return {} if !result || !result.found?

    locale = locale.to_s.sub('_', '-')

    {
      country: result.country.name(locale) || result.country.name,
      country_code: result.country.iso_code,
      region: result.subdivisions.most_specific.name(locale) || result.subdivisions.most_specific.name,
      city: result.city.name(locale) || result.city.name,
    }
  end

  def get(ip, locale = :en)
    return {} unless @mmdb

    ip = ip.to_s
    @cache["#{ip}-#{locale}"] ||= lookup(ip, locale)
  end

  def self.open_db(path)
    instance.open_db(path)
  end

  def self.get(ip, locale = :en)
    instance.get(ip, locale)
  end
end
