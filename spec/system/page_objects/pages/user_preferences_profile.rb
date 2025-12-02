# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesProfile < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/profile")
        self
      end

      def hide_profile
        find("#control-hide_profile input[type=checkbox]").click
      end

      def has_hidden_profile?
        has_css?("#control-hide_profile input[type=checkbox]:checked")
      end

      def expand_profile_details
        find(".user-main .details .controls .btn-default").click
      end

      def fill_bio(with:)
        # DEditor renders a textarea with class d-editor-input
        find(".d-editor-input").set(with)
      end

      def save
        find(".save-profile-changes").click
      end

      def cooked_bio
        find(".user-main .details .primary .bio")
      end
    end
  end
end
