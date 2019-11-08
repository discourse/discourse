# frozen_string_literal: true

module Jobs
  class BulkUserTitleUpdate < ::Jobs::Base
    UPDATE_ACTION = 'update'.freeze
    RESET_ACTION = 'reset'.freeze

    def execute(args)
      new_title = args[:new_title]
      granted_badge_id = args[:granted_badge_id]
      action = args[:action]

      case action
      when UPDATE_ACTION
        update_titles_for_granted_badge(new_title, granted_badge_id)
      when RESET_ACTION
        reset_titles_for_granted_badge(granted_badge_id)
      end
    end

    private

    ##
    # If a badge name or a system badge TranslationOverride changes
    # then we need to set all titles granted based on that badge to
    # the new name or custom translation
    def update_titles_for_granted_badge(new_title, granted_badge_id)
      DB.exec(<<~SQL, granted_title_badge_id: granted_badge_id, title: new_title, updated_at: Time.now)
        UPDATE users AS u
        SET title = :title, updated_at = :updated_at
        FROM user_profiles AS up
        WHERE up.user_id = u.id AND up.granted_title_badge_id = :granted_title_badge_id
      SQL
    end

    ##
    # Reset granted titles for a badge back to the original
    # badge name. When a system badge has its TranslationOverride
    # revoked we want to have all titles based on that translation
    # for the badge reset.
    def reset_titles_for_granted_badge(granted_badge_id)
      DB.exec(<<~SQL, granted_title_badge_id: granted_badge_id, updated_at: Time.now)
        UPDATE users AS u
        SET title = badges.name, updated_at = :updated_at
        FROM user_profiles AS up
        INNER JOIN badges ON badges.id = up.granted_title_badge_id
        WHERE up.user_id = u.id AND up.granted_title_badge_id = :granted_title_badge_id
      SQL
    end
  end
end
