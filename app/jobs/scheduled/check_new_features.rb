# frozen_string_literal: true

module Jobs

  class CheckNewFeatures < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      @new_features_json ||= DiscourseUpdates.new_features_payload
      DiscourseUpdates.update_new_features(@new_features_json)
    end
  end

end
