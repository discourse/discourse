# frozen_string_literal: true

module PageObjects
  module Components
    class ZendeskTopicActions < PageObjects::Components::Base
      def create_ticket
        find(".zendesk-topic-actions button", text: I18n.t("js.topic.create_zendesk_issue")).click
      end

      def has_no_create_button?
        has_no_css?(".zendesk-topic-actions button", text: I18n.t("js.topic.create_zendesk_issue"))
      end

      def has_ticket_link?(url)
        has_css?(
          ".zendesk-topic-actions a[href='#{url}']",
          text: I18n.t("js.topic.view_zendesk_issue"),
        )
      end

      def has_no_ticket_link?
        has_no_css?(".zendesk-topic-actions a")
      end

      def has_no_actions?
        has_no_css?(".zendesk-topic-actions")
      end

      def has_configuration_warning?
        has_css?(".zendesk-topic-actions", text: I18n.t("js.zendesk.credentials_not_setup"))
      end

      def confirmation_overflows?
        find(".zendesk-topic-actions").evaluate_script("this.scrollWidth > this.clientWidth")
      end

      def has_created_confirmation?
        has_css?(".zendesk-topic-actions", text: I18n.t("js.zendesk.ticket_created"))
      end
    end
  end
end
