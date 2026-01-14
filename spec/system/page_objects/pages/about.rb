# frozen_string_literal: true

module PageObjects
  module Pages
    class About < PageObjects::Pages::Base
      def visit
        page.visit("/about")
      end

      def has_header_title?(title)
        has_css?(".about__header h3", text: title)
      end

      def has_short_description?(content)
        has_css?(".about__header .short-description", text: content)
      end

      def has_banner_image?(upload)
        has_css?("img.about__banner-img[src=\"#{GlobalPath.full_cdn_url(upload.url)}\"]")
      end

      def has_no_banner_image?
        has_no_css?("img.about__banner-img")
      end

      def has_members_count?(count, formatted_number)
        element = find(".about__stats-item.members span")
        element.has_text?(I18n.t("js.about.member_count", count:, formatted_number:))
      end

      def has_admins_count?(count, formatted_number)
        element = find(".about__stats-item.admins span")
        element.has_text?(I18n.t("js.about.admin_count", count:, formatted_number:))
      end

      def has_moderators_count?(count, formatted_number)
        element = find(".about__stats-item.moderators span")
        element.has_text?(I18n.t("js.about.moderator_count", count:, formatted_number:))
      end

      def has_group_with_name?(name)
        has_css?(".about__#{name.downcase} h3", text: name)
      end

      def has_no_group_with_name?(name)
        has_no_css?(".about__#{name.downcase} h3", text: name)
      end

      def has_no_extra_groups?
        has_no_css?("--custom-group")
      end

      def has_site_created_less_than_1_month_ago?
        site_age_stat_element.has_text?(I18n.t("js.about.site_age.less_than_one_month"))
      end

      def has_site_created_in_months_ago?(months)
        site_age_stat_element.has_text?(I18n.t("js.about.site_age.month", count: months))
      end

      def has_site_created_in_years_ago?(years)
        site_age_stat_element.has_text?(I18n.t("js.about.site_age.year", count: years))
      end

      def edit_link
        find(".edit-about-page")
      end

      def has_edit_link?
        has_css?(".edit-about-page")
      end

      def has_no_edit_link?
        has_no_css?(".edit-about-page")
      end

      def has_traffic_info_footer?
        has_css?(".traffic-info-footer")
      end

      def has_no_traffic_info_footer?
        has_no_css?(".traffic-info-footer")
      end

      def site_activities
        PageObjects::Components::AboutPageSiteActivity.new(find(".about__activities"))
      end

      def admins_list
        PageObjects::Components::AboutPageUsersList.new(find(".about__admins"))
      end

      def moderators_list
        PageObjects::Components::AboutPageUsersList.new(find(".about__moderators"))
      end

      private

      def site_age_stat_element
        find(".about__stats-item.site-creation-date span")
      end
    end
  end
end
