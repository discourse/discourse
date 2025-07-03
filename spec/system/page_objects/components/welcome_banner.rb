# frozen_string_literal: true

module PageObjects
  module Components
    class WelcomeBanner < PageObjects::Components::Base
      def visible?
        has_css?(".welcome-banner")
      end

      def hidden?
        has_no_css?(".welcome-banner")
      end

      def invisible?
        has_css?(".welcome-banner", visible: false)
      end

      def has_anonymous_title?
        has_css?(
          ".welcome-banner .welcome-banner__title",
          text: I18n.t("js.welcome_banner.header.anonymous_members", site_name: SiteSetting.title),
        )
      end

      def has_logged_in_title?(username)
        has_css?(
          ".welcome-banner .welcome-banner__title",
          text:
            I18n.t("js.welcome_banner.header.logged_in_members", preferred_display_name: username),
        )
      end

      def has_no_subheader?
        has_no_css?(".welcome-banner .welcome-banner__subheader")
      end

      def has_anonymous_subheader?
        has_css?(
          ".welcome-banner .welcome-banner__subheader",
          text: I18n.t("js.welcome_banner.subheader.anonymous_members"),
        )
      end

      def has_logged_in_subheader?
        has_css?(
          ".welcome-banner .welcome-banner__subheader",
          text: I18n.t("js.welcome_banner.subheader.logged_in_members"),
        )
      end
    end
  end
end
