# frozen_string_literal: true

module Jobs
  class CleanUpEmailChangeRequests < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      EmailChangeRequest.where('updated_at < ?', 1.month.ago).delete_all
    end
  end
end
