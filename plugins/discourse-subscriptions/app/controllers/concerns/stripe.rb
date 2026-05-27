# frozen_string_literal: true

module DiscourseSubscriptions
  module Stripe
    extend ActiveSupport::Concern

    def self.request_opts
      { api_key: SiteSetting.discourse_subscriptions_secret_key }
    end

    def stripe_request_opts
      DiscourseSubscriptions::Stripe.request_opts
    end

    def is_stripe_configured?
      SiteSetting.discourse_subscriptions_public_key.present? &&
        SiteSetting.discourse_subscriptions_secret_key.present?
    end
  end
end
