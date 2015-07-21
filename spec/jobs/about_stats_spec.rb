require 'spec_helper'

describe Jobs::AboutStats do
  it 'caches the stats' do
    stats = { "visited" => 10 }
    About.any_instance.expects(:stats).returns(stats)
    $redis.expects(:setex).with(About.stats_cache_key, 35.minutes, stats.to_json)
    expect(described_class.new.execute({})).to eq(stats)
  end
end
