# frozen_string_literal: true

module PageObjects
  module Components
    class WelcomeBanner < PageObjects::Components::Base
      def visible?
        have_count(0).does_not_match?(browser_root.locator(".welcome-banner").filter(visible: true))
      end

      def hidden?
        have_count(0).matches?(browser_root.locator(".welcome-banner").filter(visible: true))
      end

      def invisible?
        have_count(0).does_not_match?(browser_root.locator(".welcome-banner"))
      end

      def open_search_menu
        browser_root
          .locator(".welcome-banner #welcome-banner-search-input")
          .filter(visible: true)
          .click
        self
      end

      def has_search_menu?
        have_count(0).does_not_match?(browser_root.locator(".welcome-banner .search-menu-panel"))
      end

      def has_no_search_menu?
        have_count(0).matches?(browser_root.locator(".welcome-banner .search-menu-panel"))
      end

      def has_anonymous_title?
        contain_text(
          [
            browser_text_pattern(
              I18n.t("js.welcome_banner.header.anonymous_members", site_name: SiteSetting.title),
            ),
          ],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__title").filter(visible: true),
        )
      end

      def has_logged_in_title?(username)
        contain_text(
          [
            browser_text_pattern(
              I18n.t(
                "js.welcome_banner.header.logged_in_members",
                preferred_display_name: username,
              ),
            ),
          ],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__title").filter(visible: true),
        )
      end

      def has_new_user_title?(username)
        contain_text(
          [
            browser_text_pattern(
              I18n.t("js.welcome_banner.header.new_members", preferred_display_name: username),
            ),
          ],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__title").filter(visible: true),
        )
      end

      def has_no_subheader?
        have_count(0).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__subheader").filter(visible: true),
        )
      end

      def has_anonymous_subheader?
        contain_text(
          [browser_text_pattern(I18n.t("js.welcome_banner.subheader.anonymous_members"))],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__subheader").filter(visible: true),
        )
      end

      def has_logged_in_subheader?
        contain_text(
          [browser_text_pattern(I18n.t("js.welcome_banner.subheader.logged_in_members"))],
          useInnerText: true,
        ).matches?(
          browser_root.locator(".welcome-banner .welcome-banner__subheader").filter(visible: true),
        )
      end

      def has_no_bg_img?
        have_count(0).matches?(
          browser_root.locator(".welcome-banner.--with-bg-img").filter(visible: true),
        )
      end

      def has_bg_img?(url)
        have_count(0).does_not_match?(
          browser_root.locator(
            ".welcome-banner.--with-bg-img .custom-search-banner-wrap.welcome-banner__wrap[style=#{"background-image:url(#{url});".to_json}]",
          ).filter(visible: true),
        )
      end

      def has_custom_text_color?(color)
        have_count(0).does_not_match?(
          browser_root.locator(
            ".welcome-banner .welcome-banner__title[style=#{"color:#{color};".to_json}]",
          ).filter(visible: true),
        )
      end

      def has_no_custom_text_color?(color)
        have_count(0).matches?(
          browser_root.locator(
            ".welcome-banner .welcome-banner__title[style=#{"color:#{color};".to_json}]",
          ).filter(visible: true),
        )
      end

      def above_topic_content?
        have_count(0).does_not_match?(
          browser_root.locator("#main-outlet > .--location-above-topic-content").filter(
            visible: true,
          ),
        )
      end

      def below_site_header?
        have_count(0).does_not_match?(
          browser_root.locator(".discourse-root > .--location-below-site-header").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
