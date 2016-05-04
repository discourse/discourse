require 'rails_helper'

describe Jobs::AboutStats do
  after do
    $redis.flushall
  end

  it 'caches the stats' do
    stats = About.fetch_stats.to_json
    cache_key = About.stats_cache_key

    expect($redis.get(cache_key)).to eq(nil)
    expect(described_class.new.execute({})).to eq(stats)
    expect($redis.get(cache_key)).to eq(stats)
  end
end
