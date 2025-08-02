# frozen_string_literal: true

module Migrations::Converters::Example
  class Step1 < ::Migrations::Converters::Base::Step
    title "Hello world"

    def execute
      super
      IntermediateDB::LogEntry.create(type: "info", message: "This is a test")
    end
  end
end
