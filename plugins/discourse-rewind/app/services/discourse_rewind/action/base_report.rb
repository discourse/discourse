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
        return false if ENV["DISCOURSE_REWIND_USE_REAL_DATA"] == "1"
        Rails.env.development?
      end
    end
  end
end
