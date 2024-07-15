# frozen_string_literal: true

module Migrations::Converters
  class BaseStep
    def self.run_in_parallel(value)
      @run_in_parallel = !!value
    end

    def self.run_in_parallel?
      @run_in_parallel == true
    end

    def self.title(
      value = (
        getter = true
        nil
      )
    )
      @title = value unless getter
      @title || "Converting #{name&.demodulize&.underscore&.humanize(capitalize: false)}"
    end

    attr_accessor :settings, :output_db

    def initialize(args)
      args.each { |arg, value| instance_variable_set("@#{arg}", value) if respond_to?(arg, true) }
    end

    def execute
      puts self.class.title
      puts self.class.run_in_parallel?
    end
  end
end
