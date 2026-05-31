# frozen_string_literal: true

module Migrations
  module Converter
    StepStats = Struct.new(:progress, :warning_count, :error_count)
  end
end
