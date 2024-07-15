# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Step1 < Migrations::Converters::BaseStep
    title "Hello world"

    def execute
      Migrations::IntermediateDb::LogEntry.create!(type: "info", message: "This is a test")
    end
  end
end
