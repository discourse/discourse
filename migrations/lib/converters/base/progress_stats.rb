# frozen_string_literal: true

module Migrations::Converters::Base
  class ProgressStats
    attr_accessor :progress, :warning_count, :error_count

    def initialize
      reset!
    end

    def reset!
      @progress = 1
      @warning_count = 0
      @error_count = 0
    end
  end
end
