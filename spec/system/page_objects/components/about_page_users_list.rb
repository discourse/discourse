# frozen_string_literal: true

module PageObjects
  module Components
    class AboutPageUsersList < PageObjects::Components::Base
      attr_reader :container

      def initialize(container)
        @container = container
      end

      def has_expand_button?
        have_count(0).does_not_match?(
          container.locator(".about-page-users-list__expand-button").filter(visible: true),
        )
      end

      def has_no_expand_button?
        have_count(0).matches?(
          container
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".about-page-users-list__expand-button")
            .filter(visible: true),
        )
      end

      def expandable?
        contain_text(
          browser_text_pattern(I18n.t("js.about.view_more")),
          useInnerText: true,
        ).matches?(container.locator(".about-page-users-list__expand-button").filter(visible: true))
      end

      def collapsible?
        contain_text(
          browser_text_pattern(I18n.t("js.about.view_less")),
          useInnerText: true,
        ).matches?(container.locator(".about-page-users-list__expand-button").filter(visible: true))
      end

      def expand
        container
          .locator(".about-page-users-list__expand-button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.about.view_more")))
          .click
      end

      def collapse
        container
          .locator(".about-page-users-list__expand-button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.about.view_less")))
          .click
      end

      def users
        container
          .locator(".user-info")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map do |node|
            name_first =
              node
                .locator(".name-line")
                .filter(visible: true)
                .get_attribute("class")
                .include?("--name-first")
            name_text = node.locator(".name-line .name").filter(visible: true).inner_text.strip
            username_text =
              node.locator(".name-line .username").filter(visible: true).inner_text.strip

            {
              username: node.get_attribute("data-username"),
              displayed_username: name_first ? name_text : username_text,
              displayed_name: name_first ? username_text : name_text,
              node:,
            }
          end
      end
    end
  end
end
