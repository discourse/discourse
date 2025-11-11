# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesAi < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/ai")
        self
      end

      def has_ai_preference_checked?(preference)
        page.find(".#{preference} input").checked?
      end

      def has_ai_preference?(preference)
        page.has_css?(".#{preference} input")
      end

      def has_no_ai_preference?(preference)
        page.has_no_css?(".#{preference} input")
      end

      def toggle_setting(preference)
        page.find(".#{preference} input").click
      end

      def save_changes
        page.find(".save-changes").click
      end
    end
  end
end
