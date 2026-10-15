# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateInvite < PageObjects::Modals::Base
      def modal
        browser_root.locator(".create-invite-modal").filter(visible: true)
      end

      def edit_options_link
        within_browser(modal) { browser_root.locator(".edit-link-options").filter(visible: true) }
      end

      def save_button
        within_browser(modal) { browser_root.locator(".save-invite").filter(visible: true) }
      end

      def save_and_email_button
        within_browser(modal) do
          browser_root.locator(".save-invite-and-send-email").filter(visible: true)
        end
      end

      def copy_button
        within_browser(modal) { browser_root.locator(".copy-button").filter(visible: true) }
      end

      def has_copy_button?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".copy-button").filter(visible: true),
          )
        end
      end

      def has_alert_message?(message)
        within_browser(modal) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(message)],
            useInnerText: true,
          ).matches?(browser_root.locator("#modal-alert .invite-link").filter(visible: true))
        end
      end

      def has_invite_link_input?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("input.invite-link").filter(visible: true),
          )
        end
      end

      def invite_link_input
        within_browser(modal) { browser_root.locator("input.invite-link").filter(visible: true) }
      end

      def link_limits_info_paragraph
        within_browser(modal) { browser_root.locator("p.link-limits-info").filter(visible: true) }
      end

      def form
        PageObjects::Components::FormKit.new(".create-invite-modal .form-kit")
      end

      def choose_topic(topic)
        topic_picker = PageObjects::Components::SelectKit.new(".topic-chooser")
        topic_picker.expand
        topic_picker.search(topic.id)
        topic_picker.select_row_by_index(0)
      end

      def choose_groups(groups)
        group_picker = PageObjects::Components::SelectKit.new(".group-chooser")
        group_picker.expand
        groups.each { |group| group_picker.select_row_by_value(group.id) }
        group_picker.collapse
      end
    end
  end
end
