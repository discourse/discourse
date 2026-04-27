# frozen_string_literal: true

module Jobs
  class CleanUpAiArtifacts < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      AiArtifact.where(post_id: nil).where("created_at < ?", 24.hours.ago).destroy_all
    end
  end
end
