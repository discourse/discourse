# frozen_string_literal: true

module Jobs
  class CleanUpEmailLoginCodes < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      EmailLoginCode.where("expires_at < ?", 1.day.ago).delete_all
    end
  end
end
