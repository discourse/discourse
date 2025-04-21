# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesProfile < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/profile")
        self
      end

      def hide_profile
        find(".user-hide-profile .pref-hide-profile").click
      end

      def has_hidden_profile?
        has_css?(".user-hide-profile .pref-hide-profile input[type=checkbox]:checked")
      end

      def expand_profile_details
        find(".user-main .details .controls .btn-default").click
      end

      def fill_bio(with:)
        find(".bio-composer .d-editor-input").fill_in(with:)
      end

      def save
        find(".save-button .btn-primary").click
      end

      def cooked_bio
        find(".user-main .details .primary .bio")
      end
    end
  end
end
