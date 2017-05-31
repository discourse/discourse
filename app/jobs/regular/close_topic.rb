
module Jobs
  class CloseTopic < Jobs::Base

    def execute(args)
      # This file is back temporarily to handle jobs that are enqueued
      # far in the future that haven't been migrated to the ToggleTopicClosed
      # job.
    end

  end
end
