# frozen_string_literal: true

module PageObjects
  module Components
    class PrivateMessageMap < PageObjects::Components::Base
      PRIVATE_MESSAGE_MAP_KLASS = ".topic-map__private-message-map"

      def is_visible?
        has_css?(PRIVATE_MESSAGE_MAP_KLASS)
      end

      def participants_details
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").all(".user")
      end

      def participants_count
        participants_details.length
      end

      def controls
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .controls")
      end

      def toggle_edit_participants_button
        controls.click_button(class: "add-remove-participant-btn")
      end

      def has_add_participants_button?
        controls.has_button?(class: "add-participant-btn")
      end

      def has_no_add_participants_button?
        controls.has_no_button?(class: "add-participant-btn")
      end
      def click_add_participants_button
        controls.click_button(class: "add-participant-btn")
      end

      def click_remove_participant_button(user)
        find_link(user.username).sibling(".remove-invited").click
      end

      def has_participant_details_for?(user)
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").has_link?(
          class: "user-link",
          href: "/u/#{user.username}",
        )
      end

      def has_no_participant_details_for?(user)
        find("#{PRIVATE_MESSAGE_MAP_KLASS} .participants").has_no_link?(
          class: "user-link",
          href: "/u/#{user.username}",
        )
      end
    end
  end
end
