# frozen_string_literal: true

module PageObjects
  module Pages
    class About < PageObjects::Pages::Base
      def visit(locale: nil)
        path = "/about"
        path += "?#{Discourse::LOCALE_PARAM}=#{locale}" if locale
        browser_page.goto(path).tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def has_header_title?(title)
        contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".about__header h1").filter(visible: true),
        )
      end

      def has_short_description?(content)
        contain_text([browser_text_pattern(content)], useInnerText: true).matches?(
          browser_root.locator(".about__header .short-description").filter(visible: true),
        )
      end

      def has_extended_description?(content)
        contain_text([browser_text_pattern(content)], useInnerText: true).matches?(
          browser_root.locator(".about__left-side").filter(visible: true),
        )
      end

      def has_banner_image?(upload)
        have_count(0).does_not_match?(
          browser_root.locator(
            "img.about__banner-img[src=\"#{GlobalPath.full_cdn_url(upload.url)}\"]",
          ).filter(visible: true),
        )
      end

      def has_no_banner_image?
        have_count(0).matches?(browser_root.locator("img.about__banner-img").filter(visible: true))
      end

      def has_members_count?(count, formatted_number)
        element = browser_root.locator(".about__stats-item.members span").filter(visible: true)
        contain_text(
          browser_text_pattern(I18n.t("js.about.member_count", count:, formatted_number:)),
          useInnerText: true,
        ).matches?(element)
      end

      def has_admins_count?(count, formatted_number)
        element = browser_root.locator(".about__stats-item.admins span").filter(visible: true)
        contain_text(
          browser_text_pattern(I18n.t("js.about.admin_count", count:, formatted_number:)),
          useInnerText: true,
        ).matches?(element)
      end

      def has_moderators_count?(count, formatted_number)
        element = browser_root.locator(".about__stats-item.moderators span").filter(visible: true)
        contain_text(
          browser_text_pattern(I18n.t("js.about.moderator_count", count:, formatted_number:)),
          useInnerText: true,
        ).matches?(element)
      end

      def has_group_with_name?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".about__#{name.downcase} h3").filter(visible: true),
        )
      end

      def has_no_group_with_name?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".about__#{name.downcase} h3").filter(visible: true),
        )
      end

      def has_no_extra_groups?
        have_count(0).matches?(browser_root.locator("--custom-group").filter(visible: true))
      end

      def has_site_created_less_than_1_month_ago?
        contain_text(
          browser_text_pattern(I18n.t("js.about.site_age.less_than_one_month")),
          useInnerText: true,
        ).matches?(site_age_stat_element)
      end

      def has_site_created_in_months_ago?(months)
        contain_text(
          browser_text_pattern(I18n.t("js.about.site_age.month", count: months)),
          useInnerText: true,
        ).matches?(site_age_stat_element)
      end

      def has_site_created_in_years_ago?(years)
        contain_text(
          browser_text_pattern(I18n.t("js.about.site_age.year", count: years)),
          useInnerText: true,
        ).matches?(site_age_stat_element)
      end

      def edit_link
        browser_root.locator(".edit-about-page").filter(visible: true)
      end

      def has_edit_link?
        have_count(0).does_not_match?(
          browser_root.locator(".edit-about-page").filter(visible: true),
        )
      end

      def has_no_edit_link?
        have_count(0).matches?(browser_root.locator(".edit-about-page").filter(visible: true))
      end

      def has_traffic_info_footer?
        have_count(0).does_not_match?(
          browser_root.locator(".traffic-info-footer").filter(visible: true),
        )
      end

      def has_no_traffic_info_footer?
        have_count(0).matches?(browser_root.locator(".traffic-info-footer").filter(visible: true))
      end

      def site_activities
        PageObjects::Components::AboutPageSiteActivity.new(
          browser_root.locator(".about__activities").filter(visible: true),
        )
      end

      def admins_list
        PageObjects::Components::AboutPageUsersList.new(
          browser_root.locator(".about__admins").filter(visible: true),
        )
      end

      def moderators_list
        PageObjects::Components::AboutPageUsersList.new(
          browser_root.locator(".about__moderators").filter(visible: true),
        )
      end

      private

      def site_age_stat_element
        browser_root.locator(".about__stats-item.site-creation-date span").filter(visible: true)
      end
    end
  end
end
