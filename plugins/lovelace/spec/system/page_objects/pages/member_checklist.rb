# frozen_string_literal: true

module PageObjects
  module Pages
    class LovelaceMemberChecklist < Base
      def open
        visit("/latest")
        self
      end

      def toggle(title)
        within(".lovelace-member-checklist") { click_button(title, exact: true) }
      end

      def toggle_with_keyboard(title)
        within(".lovelace-member-checklist") { find_button(title, exact: true).send_keys(:space) }
      end

      def has_compact_rows?(stacked:)
        has_css?(".lovelace-member-checklist__item", count: 3) { |row| row.evaluate_script(<<~JS) }
            (() => {
              const title = this.querySelector('strong').getBoundingClientRect();
              const description = this.querySelector('p').getBoundingClientRect();
              const action = this.querySelector('a').getBoundingClientRect();
              const check = this.querySelector('button').getBoundingClientRect();
              const descriptionPosition = #{stacked} ? description.top >= title.bottom : description.left >= title.right && description.top < title.bottom;
              return descriptionPosition && action.left >= title.right && check.right <= title.left && action.right <= window.innerWidth;
            })()
          JS
      end

      def within_reading_area?
        has_css?(".lovelace-member-checklist") { |widget| widget.evaluate_script(<<~JS) }
            (() => {
              const checklist = this.getBoundingClientRect();
              const content = document.querySelector('#main-container').getBoundingClientRect();
              return Math.abs(checklist.left - content.left) <= 1 && Math.abs(checklist.right - content.right) <= 1;
            })()
          JS
      end

      def has_compact_progress_bar?
        has_css?(".lovelace-member-checklist progress") do |progress|
          progress.evaluate_script(<<~JS)
            (() => {
              const bar = this.getBoundingClientRect();
              const checklist = this.closest('.lovelace-member-checklist').getBoundingClientRect();
              return bar.width > 0 && bar.width < checklist.width / 2;
            })()
          JS
        end
      end

      def follow_guidelines
        within(".lovelace-member-checklist") { click_link("Read guidelines", exact: true) }
      end

      def has_consistent_action_colors?
        has_css?(".lovelace-member-checklist__action", count: 3) do |link|
          # Browsers conceal visited colors; the button token also controls :visited.
          link.evaluate_script(<<~JS)
            (() => {
              const style = getComputedStyle(this);
              const probe = document.createElement('span');
              probe.style.color = style.getPropertyValue('--d-button-transparent-text-color');
              probe.style.display = 'none';
              document.body.appendChild(probe);
              const visitedColor = getComputedStyle(probe).color;
              probe.remove();
              const actual = style.color.match(/[0-9.]+/g).map(Number);
              const expected = visitedColor.match(/[0-9.]+/g).map(Number);
              // Percentage palette values can round differently by one RGB unit.
              return actual.length === expected.length && actual.every((channel, index) => Math.abs(channel - expected[index]) <= 1);
            })()
          JS
        end
      end

      def has_icon_controls?
        has_css?("button[title='Minimize'][aria-expanded='true'] .d-icon-chevron-up") &&
          has_css?("button[title='Dismiss checklist'] .d-icon-xmark")
      end

      def minimize
        click_button("Minimize", exact: true)
      end

      def expand
        click_button("Expand", exact: true)
      end

      def dismiss
        click_button("Dismiss checklist", exact: true)
      end

      def has_progress?(text)
        has_css?(".lovelace-member-checklist__progress", text: text)
      end

      def has_completed_item?(title)
        has_css?(".lovelace-member-checklist__item.--complete", text: title) do |item|
          item.has_css?("button[aria-pressed='true']")
        end
      end

      def above_welcome_banner?
        has_css?(".welcome-banner") do |banner|
          banner.evaluate_script(
            "this.getBoundingClientRect().top >= document.querySelector('.lovelace-member-checklist').getBoundingClientRect().bottom",
          )
        end
      end

      def has_minimized_checklist?
        has_button?("Expand", exact: true) && has_no_css?(".lovelace-member-checklist__items")
      end

      def has_celebration?
        has_css?(
          ".lovelace-member-checklist__celebration",
          text: I18n.t("js.lovelace.member.complete"),
        )
      end

      def has_no_checklist?
        has_no_css?(".lovelace-member-checklist")
      end

      def has_profile_link?
        has_css?(
          ".lovelace-member-checklist a[href='/my/preferences/profile']",
          text: "Complete profile",
        )
      end

      def has_responsive_layout?
        has_css?(".lovelace-member-checklist") do |widget|
          widget.evaluate_script(
            "this.getBoundingClientRect().right <= window.innerWidth && document.documentElement.scrollWidth <= window.innerWidth",
          )
        end
      end
    end
  end
end
