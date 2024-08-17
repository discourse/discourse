# frozen_string_literal: true

module PageObjects
  module Components
    class AboutPageUsersList < PageObjects::Components::Base
      attr_reader :container

      def initialize(container)
        @container = container
      end

      def has_expand_button?
        container.has_css?(".about-page-users-list__expand-button")
      end

      def has_no_expand_button?
        container.has_no_css?(".about-page-users-list__expand-button")
      end

      def expandable?
        container.find(".about-page-users-list__expand-button").has_text?(
          I18n.t("js.about.view_more"),
        )
      end

      def collapsible?
        container.find(".about-page-users-list__expand-button").has_text?(
          I18n.t("js.about.view_less"),
        )
      end

      def expand
        container.find(
          ".about-page-users-list__expand-button",
          text: I18n.t("js.about.view_more"),
        ).click
      end

      def collapse
        container.find(
          ".about-page-users-list__expand-button",
          text: I18n.t("js.about.view_less"),
        ).click
      end

      def users
        container
          .all(".user-info")
          .map do |node|
            {
              username: node["data-username"],
              displayed_username: node.find(".name-line .username").text,
              displayed_name: node.find(".name-line .name").text,
              node:,
            }
          end
      end
    end
  end
end
