# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::RefreshSubscriptionsCampaignData do
  before { SiteSetting.discourse_subscriptions_campaign_enabled = true }

  it "should execute the job only if stripe is configured" do
    DiscourseSubscriptions::Campaign.any_instance.expects(:refresh_data).once
    described_class.new.execute({})

    SiteSetting.discourse_subscriptions_public_key = "PUBLIC_KEY"
    SiteSetting.discourse_subscriptions_secret_key = "SECRET_KEY"
    described_class.new.execute({})
  end
end
