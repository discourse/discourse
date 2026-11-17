# frozen_string_literal: true

module JsonApiKit
  class ApiVersion
    include Comparable

    HEADER = "Api-Version"
    WIRE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

    class Refusal < BadRequest
      def initialize(version = nil)
        @version = version
        super()
      end

      def source = { header: HEADER }

      private

      attr_reader :version
    end

    class Required < Refusal
      def title = "#{HEADER} is required"

      def detail = "Send #{HEADER}: #{version}."
    end

    class NotADate < Refusal
      def title = "#{HEADER} is not a date"

      def detail = "#{HEADER} must be written as YYYY-MM-DD."
    end

    class Unknown < Refusal
      def title = "No such version"

      def detail = "The first version is #{version}."
    end

    class InTheFuture < Refusal
      def title = "#{HEADER} is in the future"

      def detail
        "#{HEADER} must not be later than today in UTC. The current version is #{version}."
      end
    end

    def self.parse(raw)
      raise NotADate unless WIRE_FORMAT.match?(raw)
      new(Date.iso8601(raw))
    rescue Date::Error
      raise NotADate
    end

    attr_reader :date

    def initialize(date)
      @date = date
    end

    def <=>(other)
      return unless other.is_a?(self.class)
      date <=> other.date
    end

    def eql?(other) = (self <=> other) == 0

    def hash = date.hash

    def future? = date.future?

    def to_s = date.iso8601
  end
end
