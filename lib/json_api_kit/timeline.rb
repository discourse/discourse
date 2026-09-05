# frozen_string_literal: true

module JsonApiKit
  class Timeline
    # The day this API was first released.
    FIRST_RELEASE = ApiVersion.parse("2026-08-31")

    class << self
      delegate :first, :current, :resolve, to: :core

      private

      def core = @core ||= new([FIRST_RELEASE])
    end

    def initialize(versions)
      @versions = versions.sort
    end

    def first = versions.first

    def current = versions.last

    def resolve(raw)
      raise ApiVersion::Required.new(current) if raw.blank?
      pin = ApiVersion.parse(raw)
      raise ApiVersion::InTheFuture.new(current) if pin.future?
      versions.reverse_each.detect { it <= pin } or raise ApiVersion::Unknown.new(first)
    end

    private

    attr_reader :versions
  end
end
