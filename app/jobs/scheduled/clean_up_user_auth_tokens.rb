# frozen_string_literal: true

module Jobs
  class CleanUpUserAuthTokens < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      UserAuthToken.cleanup!
    end
  end
end
