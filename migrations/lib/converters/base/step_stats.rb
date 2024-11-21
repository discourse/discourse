# frozen_string_literal: true

module Migrations::Converters::Base
  StepStats = Struct.new(:progress, :warning_count, :error_count)
end
