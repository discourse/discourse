# frozen_string_literal: true

module Jobs
  class CleanUpAssociatedGroups < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      AssociatedGroup.cleanup!
    end
  end
end
