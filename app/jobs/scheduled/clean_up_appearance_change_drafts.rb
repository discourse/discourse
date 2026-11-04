# frozen_string_literal: true

module Jobs
  # Removes appearance changes that were saved but never made live, so
  # abandoned drafts don't pile up as unused themes and palettes.
  class CleanUpAppearanceChangeDrafts < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      AppearanceChange.abandoned_drafts.find_each do |appearance_change|
        appearance_change.discard!
      rescue => e
        Discourse.handle_job_exception(
          e,
          message: "Cleaning up an appearance change draft",
          extra: {
            appearance_change_id: appearance_change.id,
          },
        )
      end
    end
  end
end
