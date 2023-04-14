# frozen_string_literal: true

require "faker"

module Faker
  class Discourse < Base
    class << self
      def tag
        fetch("discourse.tags")
      end

      def category
        fetch("discourse.categories")
      end

      def group
        fetch("discourse.groups")
      end

      def topic
        fetch("discourse.topics")
      end
    end
  end
end
