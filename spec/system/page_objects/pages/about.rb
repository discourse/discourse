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
        has_css?("img.about__banner[src=\"#{GlobalPath.full_cdn_url(upload.url)}\"]")
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
    end
  end
end
