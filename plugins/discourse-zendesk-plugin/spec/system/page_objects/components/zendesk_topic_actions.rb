# frozen_string_literal: true

module PageObjects
  module Components
    class ZendeskTopicActions < PageObjects::Components::Base
      SELECTOR = ".zendesk-topic-actions"

      def click_create
        within(SELECTOR) { click_button(I18n.t("js.topic.create_zendesk_issue")) }
        self
      end

      def has_create_action?
        within(SELECTOR) { has_button?(I18n.t("js.topic.create_zendesk_issue")) }
      end

      def has_view_action?(url)
        within(SELECTOR) { has_link?(I18n.t("js.topic.view_zendesk_issue"), href: url) }
      end

      def has_no_actions?
        has_no_css?(SELECTOR)
      end

      def has_no_credentials_warning?
        has_no_text?(I18n.t("js.zendesk.credentials_not_setup"))
      end
    end
  end
end
