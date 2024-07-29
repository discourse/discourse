# frozen_string_literal: true

module Migrations::Converters::Base
  class StepExecutor
    def initialize(step)
      @step = step
    end

    def execute
      puts @step.class.title
      @step.execute
    end
  end
end
