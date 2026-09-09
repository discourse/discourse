# frozen_string_literal: true

module DiscourseSubscriptions
  module Stripe
    extend ActiveSupport::Concern

    def self.client(api_key: SiteSetting.discourse_subscriptions_secret_key)
      raise ::Stripe::AuthenticationError, "Stripe secret key is not configured" if api_key.blank?

      ::Stripe::StripeClient.new(api_key, stripe_version: "2024-04-10")
    end

    def self.configured?
      SiteSetting.discourse_subscriptions_public_key.present? &&
        SiteSetting.discourse_subscriptions_secret_key.present?
    end

    def is_stripe_configured?
      DiscourseSubscriptions::Stripe.configured?
    end

    private

    def stripe_client
      @stripe_client ||= DiscourseSubscriptions::Stripe.client
    end
  end
end
