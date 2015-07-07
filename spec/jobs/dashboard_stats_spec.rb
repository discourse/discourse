require 'spec_helper'

describe Jobs::DashboardStats do
  it 'caches the stats' do
    json = { "visited" => 10 }
    AdminDashboardData.any_instance.expects(:as_json).returns(json)
    $redis.expects(:setex).with(AdminDashboardData.stats_cache_key, 35.minutes, json.to_json)
    expect(described_class.new.execute({})).to eq(json)
  end
end
