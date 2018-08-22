class AdminDashboardNextData
  include StatsCacheable

  def initialize(opts = {})
    @opts = opts
  end

  def self.fetch_stats
    new.as_json
  end

  def get_json
    {}
  end

  def as_json(_options = nil)
    @json ||= get_json
  end

  def self.reports(source)
    source.map { |type| Report.find(type).as_json }
  end

  def self.stats_cache_key
    "dashboard-next-data-#{Report::SCHEMA_VERSION}"
  end
end
