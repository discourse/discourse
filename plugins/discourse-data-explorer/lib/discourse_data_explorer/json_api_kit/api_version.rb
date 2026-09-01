# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # An API version: a calendar date (Stripe-style date-based versioning).
    # See docs/versioning-design.md.
    class ApiVersion
      include Comparable

      Invalid = Class.new(StandardError)

      FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

      attr_reader :date

      class << self
        def parse(value)
          str = value.to_s
          raise Invalid, "invalid version format: #{value.inspect}" unless str.match?(FORMAT)
          new(Date.iso8601(str))
        rescue Date::Error
          raise Invalid, "invalid version date: #{value.inspect}"
        end
      end

      def initialize(date)
        @date = date
      end

      def <=>(other) = date <=> other.date
      def eql?(other) = other.is_a?(self.class) && date == other.date
      def hash = [self.class, date].hash
      def future?(today: Date.current) = date > today
      def to_s = date.iso8601
    end
  end
end
