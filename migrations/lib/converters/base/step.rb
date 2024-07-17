# frozen_string_literal: true

module Migrations::Converters::Base
  class Step
    IntermediateDB = Migrations::Database::IntermediateDB

    attr_accessor :settings, :output_db

    def initialize(args)
      args.each { |arg, value| instance_variable_set("@#{arg}", value) if respond_to?(arg, true) }
    end

    def execute
      puts self.class.title
    end

    class << self
      def title(
        value = (
          getter = true
          nil
        )
      )
        @title = value unless getter
        @title.presence || "Converting #{name&.demodulize&.underscore&.humanize(capitalize: false)}"
      end
    end
  end
end
