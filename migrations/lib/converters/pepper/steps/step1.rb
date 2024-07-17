# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Step1 < Migrations::Converters::Base::BasicStep
    title "Hello world"

    def execute
      IntermediateDB::LogEntry.create!(type: "info", message: "This is a test")
    end
  end
end
