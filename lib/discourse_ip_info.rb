require_dependency 'maxminddb'

class DiscourseIpInfo
  include Singleton

  def initialize
    begin
      @mmdb_filename = File.join(Rails.root, 'vendor', 'data', 'GeoLite2-City.mmdb')
      @mmdb = MaxMindDB.new(@mmdb_filename, MaxMindDB::LOW_MEMORY_FILE_READER)
    rescue
    end

    @cache = LruRedux::ThreadSafeCache.new(1000)
  end

  def lookup(ip)
    return {} unless @mmdb

    result = @mmdb.lookup(ip)
    return {} unless result.found?

    {
      country: result.country.name,
      country_code: result.country.iso_code,
      region: result.subdivisions.most_specific.name,
      city: result.city.name,
    }
  end

  def get(ip)
    return {} unless @mmdb

    @cache[ip] || @cache[ip] = lookup(ip)
  end

  def self.get(ip)
    instance.get(ip)
  end
end
