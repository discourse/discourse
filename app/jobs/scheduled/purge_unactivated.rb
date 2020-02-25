# frozen_string_literal: true

module Jobs
  class PurgeUnactivated < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      User.purge_unactivated
    end
  end
end
