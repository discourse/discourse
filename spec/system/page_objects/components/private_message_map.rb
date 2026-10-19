# frozen_string_literal: true

module PageObjects
  module Components
    class PrivateMessageMap < PageObjects::Components::Base
      PRIVATE_MESSAGE_MAP_KLASS = ".topic-map__private-message-map"

      def is_visible?
        have_count(0).does_not_match?(
          browser_root.locator(PRIVATE_MESSAGE_MAP_KLASS).filter(visible: true),
        )
      end

      def participants_details
        browser_root
          .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
          .filter(visible: true)
          .locator(".user")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def participants_count
        participants_details.length
      end

      def controls
        browser_root.locator("#{PRIVATE_MESSAGE_MAP_KLASS} .controls").filter(visible: true)
      end

      def toggle_edit_participants_button
        controls
          .get_by_role("button")
          .and(controls.locator(".#{"add-remove-participant-btn".to_s.split.join(".")}"))
          .filter(visible: true)
          .click
      end

      def has_add_participants_button?
        have_count(0).does_not_match?(
          controls
            .get_by_role("button")
            .and(controls.locator(".#{"add-participant-btn".to_s.split.join(".")}"))
            .filter(visible: true),
        )
      end

      def has_no_add_participants_button?
        have_count(0).matches?(
          controls
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .get_by_role("button")
            .and(
              controls
                .tap do |parent|
                  parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
                end
                .locator(".#{"add-participant-btn".to_s.split.join(".")}"),
            )
            .filter(visible: true),
        )
      end

      def click_add_participants_button
        controls
          .get_by_role("button")
          .and(controls.locator(".#{"add-participant-btn".to_s.split.join(".")}"))
          .filter(visible: true)
          .click
      end

      def click_remove_participant_button(user)
        browser_root
          .get_by_role("link", name: user.username, exact: true)
          .locator("xpath=..")
          .locator(".remove-invited")
          .click
      end

      def has_participant_details_for?(user)
        have_count(0).does_not_match?(
          browser_root
            .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
            .filter(visible: true)
            .get_by_role("link")
            .and(
              browser_root
                .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
                .filter(visible: true)
                .locator(".#{"user-link".to_s.split.join(".")}"),
            )
            .and(
              browser_root
                .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
                .filter(visible: true)
                .locator("[href=#{"/u/#{user.username}".to_s.to_json}]"),
            )
            .filter(visible: true),
        )
      end

      def has_no_participant_details_for?(user)
        have_count(0).matches?(
          browser_root
            .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .get_by_role("link")
            .and(
              browser_root
                .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
                .filter(visible: true)
                .tap do |parent|
                  parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
                end
                .locator(".#{"user-link".to_s.split.join(".")}"),
            )
            .and(
              browser_root
                .locator("#{PRIVATE_MESSAGE_MAP_KLASS} .participants")
                .filter(visible: true)
                .tap do |parent|
                  parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
                end
                .locator("[href=#{"/u/#{user.username}".to_s.to_json}]"),
            )
            .filter(visible: true),
        )
      end
    end
  end
end
