# frozen_string_literal: true

module ::Jobs
  class RefreshSubscriptionsCampaignData < ::Jobs::Scheduled
    include ::DiscourseSubscriptions::Stripe
    every 30.minutes

    def execute(args)
      return unless SiteSetting.discourse_subscriptions_campaign_enabled && is_stripe_configured?
      DiscourseSubscriptions::Campaign.new.refresh_data
    end
  end
end
