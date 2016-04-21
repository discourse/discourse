require 'rails_helper'

describe Jobs::DashboardStats do
  after do
    $redis.flushall
  end

  it 'caches the stats' do
    Timecop.freeze do
      stats = AdminDashboardData.fetch_stats.to_json
      cache_key = AdminDashboardData.stats_cache_key

      expect($redis.get(cache_key)).to eq(nil)
      expect(described_class.new.execute({})).to eq(stats)
      expect($redis.get(cache_key)).to eq(stats)
    end
  end
end
