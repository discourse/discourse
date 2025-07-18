# frozen_string_literal: true

require "rails_helper"

describe SiteSerializer do
  fab!(:user)
  let(:guardian) { Guardian.new(user) }

  before do
    Discourse.redis.del("subscriptions_goal_met_date")
    SiteSetting.discourse_subscriptions_enabled = true
    SiteSetting.discourse_subscriptions_campaign_enabled = true
  end

  it "is false if the goal_met date is < 7 days old" do
    Discourse.redis.set("subscriptions_goal_met_date", 10.days.ago)
    data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

    expect(data[:show_campaign_banner]).to be false
  end

  it "is true if the goal_met date is > 7 days old" do
    Discourse.redis.set("subscriptions_goal_met_date", 1.days.ago)
    data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

    expect(data[:show_campaign_banner]).to be true
  end

  it "fails gracefully if the goal_met date is invalid" do
    Discourse.redis.set("subscriptions_goal_met_date", "bananas")
    data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(data[:show_campaign_banner]).to be false
  end
end
