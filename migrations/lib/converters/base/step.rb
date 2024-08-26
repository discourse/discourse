# frozen_string_literal: true

module Migrations::Converters::Base
  class Step
    IntermediateDB = ::Migrations::Database::IntermediateDB

    attr_accessor :settings

    def initialize(args = {})
      args.each { |arg, value| instance_variable_set("@#{arg}", value) if respond_to?(arg, true) }
    end

    def execute
      # do nothing
    end

    class << self
      def title(
        value = (
          getter = true
          nil
        )
      )
        @title = value unless getter
        @title.presence ||
          I18n.t(
            "converter.default_step_title",
            type: name&.demodulize&.underscore&.humanize(capitalize: false),
          )
      end
    end
  end
end
