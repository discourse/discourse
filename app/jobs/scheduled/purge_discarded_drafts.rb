# frozen_string_literal: true

module Jobs
  class PurgeDiscardedDrafts < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      Draft.purge_discarded!
    end
  end
end
