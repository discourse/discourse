require_dependency 'maxminddb'

class DiscourseIpInfo
  include Singleton

  def initialize
    begin
      @mmdb_filename = File.join(Rails.root, 'vendor', 'data', 'GeoLite2-City.mmdb')
      @mmdb = MaxMindDB.new(@mmdb_filename, MaxMindDB::LOW_MEMORY_FILE_READER)
      @cache = LruRedux::ThreadSafeCache.new(1000)
    rescue Errno::ENOENT => e
      Rails.logger.warn("MaxMindDB could not be found: #{e}")
    rescue
      Rails.logger.warn("MaxMindDB could not be loaded.")
    end
  end

  def lookup(ip)
    return {} unless @mmdb

    begin
      result = @mmdb.lookup(ip)
    rescue
      Rails.logger.error("IP #{ip} could not be looked up in MaxMindDB.")
    end

    return {} if !result || !result.found?

    {
      country: result.country.name,
      country_code: result.country.iso_code,
      region: result.subdivisions.most_specific.name,
      city: result.city.name,
    }
  end

  def get(ip)
    return {} unless @mmdb

    @cache[ip] ||= lookup(ip)
  end

  def self.get(ip)
    instance.get(ip)
  end
end
