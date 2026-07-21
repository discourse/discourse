# frozen_string_literal: true

module PageObjects
  module Components
    class SelectShowcases < PageObjects::Components::Base
      REVIEWERS = "[data-test-select-showcase='reviewers']"
      TAGS = "[data-test-select-showcase='tags']"
      NOTIFICATIONS = "[data-test-select-showcase='notifications']"

      def has_resolved_reviewers?(count:)
        has_css?("#{REVIEWERS} .d-combobox__chip", count: count) &&
          has_css?("#{REVIEWERS} .d-combobox__chip-label", text: "maya") &&
          has_css?("#{REVIEWERS} .d-combobox__chip-label", text: "deleted-user")
      end

      def reviewer_chips_wrapped?
        page.evaluate_script(<<~JS)
          (() => {
            const chips = [
              ...document.querySelectorAll(
                "#{REVIEWERS} .d-combobox__chip"
              ),
            ];
            return new Set(chips.map((chip) => chip.offsetTop)).size > 1;
          })()
        JS
      end

      def open_reviewers
        find("#{REVIEWERS} .d-combobox__input").click
      end

      def has_disabled_reviewer?(name)
        has_css?("[role='listbox'] [role='option'][aria-disabled='true']", text: name)
      end

      def create_tag(name)
        find("#{TAGS} .d-combobox__trigger").click
        find(".d-combobox__filter").fill_in(with: name)
        find("[role='listbox'] [role='option']", text: "Create “#{name}”").click
      end

      def has_selected_tag?(name)
        has_css?("#{TAGS} .d-combobox__chip-label", text: name)
      end

      def tag_picker_expanded?
        find("#{TAGS} .d-combobox__trigger")["aria-expanded"] == "true"
      end

      def close_tag_picker
        page.send_keys(:escape)
      end

      def use_notification_action
        find("#{NOTIFICATIONS} .d-combobox__trigger").click
        find("[role='listbox'] [role='option']", text: "Manage notification settings").click
      end

      def has_notification_selection?(name)
        has_css?("#{NOTIFICATIONS} .d-combobox__value", text: name)
      end

      def has_notification_action_count?(count)
        has_css?(
          "#{NOTIFICATIONS} [data-test-notification-event]",
          text: "The action row was used #{count} time without changing the selection.",
        )
      end
    end
  end
end
