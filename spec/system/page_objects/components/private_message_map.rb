# frozen_string_literal: true

module PageObjects
  module Components
    class PrivateMessageMap < PageObjects::Components::Base
      PRIVATE_MESSAGE_MAP_KLASS = ".private-message-map"
      def is_visible?
        has_css?(PRIVATE_MESSAGE_MAP_KLASS)
      end

      def participants_details
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").all(".user")
      end

      def toggle_edit_participants_button
        # find_button("add-remove-participant").click
        find(".add-remove-participant-btn").click
      end

      def has_invite_participants_button?
        has_css?("#{PRIVATE_MESSAGE_MAP_KLASS} .controls .add-participant-btn")
      end

      def has_no_invite_participants_button?
        has_no_css?("#{PRIVATE_MESSAGE_MAP_KLASS} .controls .add-participant-btn")
      end
      def click_invite_participants_button
      end

      def click_remove_participant_button(user)
        find_link(user.username).sibling(".remove-invited").click
      end

      def has_participant_details_for?(user)
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").has_link?(user.username)
      end

      def has_no_participant_details_for?(user)
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").has_no_link?(user.username)
      end
    end
  end
end
