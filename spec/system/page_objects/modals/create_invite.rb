# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateInvite < PageObjects::Modals::Base
      def modal
        find(".create-invite-modal")
      end

      def edit_options_link
        within(modal) { find(".edit-link-options") }
      end

      def save_button
        within(modal) { find(".save-invite") }
      end

      def copy_button
        within(modal) { find(".copy-button") }
      end

      def has_copy_button?
        within(modal) { has_css?(".copy-button") }
      end

      def has_invite_link_input?
        within(modal) { has_css?("input.invite-link") }
      end

      def invite_link_input
        within(modal) { find("input.invite-link") }
      end

      def link_limits_info_paragraph
        within(modal) { find("p.link-limits-info") }
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
