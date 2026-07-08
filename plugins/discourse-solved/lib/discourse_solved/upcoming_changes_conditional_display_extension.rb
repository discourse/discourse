# frozen_string_literal: true

module DiscourseSolved
  module UpcomingChangesConditionalDisplayExtension
    def should_display_enable_solved_badges?
      SiteSetting.solved_enabled
    end
  end
end
