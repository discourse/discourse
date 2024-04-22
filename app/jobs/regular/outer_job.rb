# frozen_string_literal: true

module Jobs
  class OuterJob < ::Jobs::Base
    def execute(args)
      puts "Starting outer job"
      Jobs.enqueue(:inner_job)
      puts "Done outer job"
    end
  end
end
