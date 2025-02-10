# frozen_string_literal: true

module Jobs
  class CleanUpDrafts < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      Draft.cleanup!
    end
  end
end
