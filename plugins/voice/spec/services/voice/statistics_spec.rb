# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::Statistics do
  fab!(:user)
  fab!(:room, :voice_room)

  before do
    freeze_time
    SiteSetting.voice_enabled = true
    SiteSetting.voice_analytics_enabled = true
  end

  it "counts each participant once across rooms and repeat visits in the last seven days" do
    Fabricate(:voice_session, user: user, room: room, joined_at: 1.day.ago)
    Fabricate(:voice_session, user: user, joined_at: 2.days.ago)
    Fabricate(:voice_session, room: room, joined_at: 6.days.ago, left_at: nil)
    Fabricate(:voice_session, room: room, joined_at: 7.days.ago)
    Fabricate(:voice_session, room: room, joined_at: 8.days.ago)

    expect(described_class.about_users).to eq("7_days": 2)
    expect(About.fetch_stats[:voice_users_7_days]).to eq(2)
  end

  it "returns zero when nobody joined recently" do
    expect(described_class.about_users).to eq("7_days": 0)
  end

  it "omits the statistic when voice is disabled" do
    SiteSetting.voice_enabled = false

    expect(About.fetch_stats).not_to have_key(:voice_users_7_days)
  end

  it "omits the statistic when analytics are disabled" do
    SiteSetting.voice_analytics_enabled = false

    expect(About.fetch_stats).not_to have_key(:voice_users_7_days)
  end
end
