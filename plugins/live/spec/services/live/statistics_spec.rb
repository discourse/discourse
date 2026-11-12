# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::Statistics do
  fab!(:user)
  fab!(:room, :live_room)

  before do
    freeze_time
    SiteSetting.live_enabled = true
    SiteSetting.live_analytics_enabled = true
  end

  it "counts each participant once across rooms and repeat visits in the last seven days" do
    Fabricate(:live_session, user: user, room: room, joined_at: 1.day.ago)
    Fabricate(:live_session, user: user, joined_at: 2.days.ago)
    Fabricate(:live_session, room: room, joined_at: 6.days.ago, left_at: nil)
    Fabricate(:live_session, room: room, joined_at: 7.days.ago)
    Fabricate(:live_session, room: room, joined_at: 8.days.ago)

    expect(described_class.about_users).to eq("7_days": 2)
    expect(About.fetch_stats[:live_users_7_days]).to eq(2)
  end

  it "returns zero when nobody joined recently" do
    expect(described_class.about_users).to eq("7_days": 0)
  end

  it "omits the statistic when live is disabled" do
    SiteSetting.live_enabled = false

    expect(About.fetch_stats).not_to have_key(:live_users_7_days)
  end

  it "omits the statistic when analytics are disabled" do
    SiteSetting.live_analytics_enabled = false

    expect(About.fetch_stats).not_to have_key(:live_users_7_days)
  end
end
