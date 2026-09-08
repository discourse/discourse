# frozen_string_literal: true

module DiscourseSubscriptions
  module Stripe
    extend ActiveSupport::Concern

    class << self
      def request_opts
        { api_key: SiteSetting.discourse_subscriptions_secret_key }
      end

      def configured?
        SiteSetting.discourse_subscriptions_public_key.present? &&
          SiteSetting.discourse_subscriptions_secret_key.present?
      end
    end

    def stripe_request_opts
      DiscourseSubscriptions::Stripe.request_opts
    end

    def is_stripe_configured?
      DiscourseSubscriptions::Stripe.configured?
    end
  end
end
