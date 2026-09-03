# frozen_string_literal: true

module PageObjects
  module Components
    # Drives the rich `DSelect` examples on the styleguide select page.
    #
    # Every lookup that reaches into an open overlay is scoped by the example's `@identifier`
    # rather than by `[role='listbox']` alone: the overlay is portaled out of the example's
    # wrapper, so an unscoped query reads whichever panel happens to be open. `.d-combobox__filter`
    # is the sharpest case — every open `button`/`static` panel renders one.
    class SelectExamples < PageObjects::Components::Base
      REVIEWERS = "[data-test-select-showcase='reviewers']"
      TAGS = "[data-test-select-showcase='tags']"
      NOTIFICATIONS = "[data-test-select-showcase='notifications']"

      def panel(identifier)
        "[data-identifier='sg-#{identifier}'][data-content]"
      end

      def has_resolved_reviewers?(count:)
        has_css?("#{REVIEWERS} .d-combobox__chip", count: count) &&
          has_css?("#{REVIEWERS} .d-combobox__chip-label", text: "maya") &&
          has_css?("#{REVIEWERS} .d-combobox__chip-label", text: "deleted-user")
      end

      # The chips wrap only because the control is width-constrained; this asserts the wrap by
      # comparing offsets rather than by measuring, so it stays true across themes.
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
        has_css?("#{panel("reviewers")} [role='option'][aria-disabled='true']", text: name)
      end

      def create_tag(name)
        find("#{TAGS} .d-combobox__trigger").click
        find("#{panel("tags")} .d-combobox__filter").fill_in(with: name)
        find("#{panel("tags")} [role='option']", text: "Create “#{name}”").click
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

      def close_open_panel
        page.send_keys(:escape)
      end

      def open_computed_timezones
        find("[data-identifier='sg-content-computed'][data-trigger]").click
      end

      def move_computed_clock_near_next_minute
        page.execute_script(<<~JS)
          window.__selectExamplesOriginalDate = window.Date;
          const NativeDate = window.Date;
          const offset = 59_600 - (NativeDate.now() % 60_000);

          window.Date = class extends NativeDate {
            constructor(...args) {
              super(...(args.length ? args : [NativeDate.now() + offset]));
            }

            static now() {
              return NativeDate.now() + offset;
            }
          };
        JS
      end

      def computed_times
        all("#{panel("content-computed")} .select-examples__meta", minimum: 3).map(&:text)
      end

      def restore_computed_clock
        page.execute_script(<<~JS)
          if (window.__selectExamplesOriginalDate) {
            window.Date = window.__selectExamplesOriginalDate;
          }
        JS
      end

      def open_divided_timezones
        find("[data-identifier='sg-divided'][data-trigger]").click
      end

      def open_notifications
        find("#{NOTIFICATIONS} .d-combobox__trigger").click
      end

      def has_notification_icons?
        return false unless has_css?("#{panel("notifications")} [role='option']", minimum: 1)

        page.evaluate_script(<<~JS)
          (() => {
            const options = [
              ...document.querySelectorAll(
                "#{panel("notifications")} [role='option']"
              ),
            ];
            return (
              options.length > 0 &&
              options.every((option) => option.querySelector(".d-icon"))
            );
          })()
        JS
      end

      def has_timezone_offset_badges?(minimum:)
        has_css?("#{panel("content-computed")} .select-examples__timezone-offset", minimum: minimum)
      end

      def has_no_timezone_clock_icons?
        has_no_css?("#{panel("content-computed")} .d-icon-clock")
      end

      def has_no_computed_dividers?
        has_no_css?("#{panel("content-computed")} .d-combobox__divider")
      end

      def has_timezone_dividers?(minimum:)
        has_css?("#{panel("divided")} .d-combobox__divider", minimum: minimum)
      end

      # No overlay anywhere on the page. Deliberately document-wide rather than scoped: the point
      # is that NOTHING is left open to sit on top of the next trigger.
      def has_no_open_panel?
        page.has_no_css?("#d-menu-portals [role='listbox']")
      end

      def use_notification_action
        find("#{NOTIFICATIONS} .d-combobox__trigger").click
        find(
          "#{panel("notifications")} [role='option']",
          text: "Manage notification settings",
        ).click
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
