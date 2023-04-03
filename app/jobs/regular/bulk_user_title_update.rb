# frozen_string_literal: true

module Jobs
  class BulkUserTitleUpdate < ::Jobs::Base
    UPDATE_ACTION = "update"
    RESET_ACTION = "reset"

    def execute(args)
      new_title = args[:new_title]
      granted_badge_id = args[:granted_badge_id]
      action = args[:action]
      badge =
        begin
          Badge.find(granted_badge_id)
        rescue StandardError
          nil
        end

      return unless badge # Deleted badge protection

      case action
      when UPDATE_ACTION
        badge.update_user_titles!(new_title)
      when RESET_ACTION
        badge.reset_user_titles!
      end
    end
  end
end
