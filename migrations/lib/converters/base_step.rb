# frozen_string_literal: true

module Migrations::Converters
  class BaseStep
    attr_accessor :settings, :output_db

    def initialize(args)
      args.each { |arg, value| instance_variable_set("@#{arg}", value) if respond_to?(arg, true) }
    end

    def execute
      puts self.class.title
    end

    class << self
      attr_writer :title

      def title
        @title ||= "Converting #{name.demodulize.underscore.humanize(capitalize: false)}"
      end
    end
  end
end
