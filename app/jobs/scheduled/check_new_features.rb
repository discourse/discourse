# frozen_string_literal: true

module Jobs

  class CheckNewFeatures < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      DiscourseUpdates.perform_new_feature_check
    end
  end

end
