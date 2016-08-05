require 'rails_helper'

describe Jobs::DashboardStats do
  it 'caches the stats' do
    Timecop.freeze do
      begin
        stats = AdminDashboardData.fetch_stats.to_json
        cache_key = AdminDashboardData.stats_cache_key

        expect($redis.get(cache_key)).to eq(nil)
        expect(described_class.new.execute({})).to eq(stats)
        expect($redis.get(cache_key)).to eq(stats)
      ensure
        $redis.del(cache_key)
      end
    end
  end
end
