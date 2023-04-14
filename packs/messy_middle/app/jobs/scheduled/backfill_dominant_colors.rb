# frozen_string_literal: true

module Jobs
  class BackfillDominantColors < ::Jobs::Scheduled
    every 15.minutes

    def execute(args)
      Upload.backfill_dominant_colors!(25)
    end
  end
end
