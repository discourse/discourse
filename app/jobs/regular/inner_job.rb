# frozen_string_literal: true

module Jobs
  class InnerJob < ::Jobs::Base
    def execute(args)
      puts "Starting inner job"
      puts "Finishing inner job"
    end
  end
end
