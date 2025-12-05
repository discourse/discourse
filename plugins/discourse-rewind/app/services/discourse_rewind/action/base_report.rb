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
    end
  end
end
