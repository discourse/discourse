# frozen_string_literal: true

module Migrations
  module Conversion
    StepStats = Struct.new(:progress, :warning_count, :error_count)
  end
end
