# frozen_string_literal: true

module DiscourseRewind
  module Action
    class BaseReport < Service::ActionBase
      option :user
      option :date

      def call
        raise NotImplementedError
      end

      def self.enabled?
        true
      end

      def should_use_fake_data?
        Rails.env.development?
      end
    end
  end
end
