# frozen_string_literal: true

module Migrations
  module Converters
    module Base
      StepStats = Struct.new(:progress, :warning_count, :error_count)
    end
  end
end
