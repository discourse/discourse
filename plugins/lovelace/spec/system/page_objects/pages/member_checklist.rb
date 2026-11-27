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

      def follow_link_with_keyboard(text)
        within(".lovelace-member-checklist") { find_link(text, exact: true).send_keys(:enter) }
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

      def complete_with_paused_clock(title, preview: false)
        prepare_completion_visuals
        page.driver.with_playwright_page do |browser|
          browser.clock.install(time: Time.current)
          browser.clock.pause_at(1.second.from_now)
          button = browser.get_by_role("button", name: title, exact: true)
          # Dispatch directly because Playwright's actionability checks need animation frames.
          if preview
            button.dispatch_event("click")
          else
            browser.expect_response("**/lovelace/member-checklist.json") do
              button.dispatch_event("click")
              browser.clock.run_for(100)
            end
          end
          browser.clock.run_for(100)
        end
        advance_countdown_animation(0)
      end

      def prepare_completion_visuals
        page.execute_script(<<~JS)
          // Restore native transitions so the fade can be inspected independently of the clock.
          document.querySelectorAll('style').forEach(style => {
            if (style.textContent.includes('animation-duration: 0s !important;') && style.textContent.includes('scroll-behavior: auto !important;')) {
              style.remove();
            }
          });
          const checklist = document.querySelector('.lovelace-member-checklist');
          new MutationObserver(() => {
            checklist.getAnimations().forEach(animation => {
              if (animation.transitionProperty === 'opacity') {
                animation.pause();
                animation.currentTime = animation.effect.getTiming().duration / 2;
              }
            });
          }).observe(checklist, { attributes: true, attributeFilter: ['class'] });
        JS
      end

      def advance_countdown_animation(milliseconds)
        find(".lovelace-member-checklist__countdown-bar").execute_script(<<~JS, milliseconds)
          const animation = this.getAnimations()[0];
          animation.pause();
          animation.currentTime = arguments[0];
        JS
      end

      def has_countdown_fraction?(fraction)
        has_compact_dismissal_timer? &&
          has_css?(".lovelace-member-checklist__countdown-bar") do |bar|
            bar.evaluate_script(
              "Math.abs(new DOMMatrixReadOnly(getComputedStyle(this).transform).m11 - #{fraction}) < 0.01",
            )
          end
      end

      def has_compact_dismissal_timer?
        has_no_css?(".lovelace-member-checklist__auto-dismiss", visible: :all) &&
          has_css?(".lovelace-member-checklist__completion-actions") do |actions|
            actions.evaluate_script(<<~JS)
              (() => {
                const button = this.querySelector('.lovelace-member-checklist__close').getBoundingClientRect();
                const timer = this.querySelector('.lovelace-member-checklist__countdown').getBoundingClientRect();
                const checklist = this.closest('.lovelace-member-checklist').getBoundingClientRect();
                return Math.abs(timer.left - button.left) < 1 && Math.abs(timer.right - button.right) < 1 && timer.top > button.bottom && timer.height === 2 && timer.width < checklist.width / 2;
              })()
            JS
          end
      end

      def use_rtl_layout
        page.execute_script("document.documentElement.dir = 'rtl'")
      end

      def has_countdown_origin_on_right?
        has_css?(".lovelace-member-checklist__countdown-bar") do |bar|
          bar.evaluate_script(
            "Math.abs(parseFloat(getComputedStyle(this).transformOrigin) - this.clientWidth) < 1",
          )
        end
      end

      def has_stepped_countdown?
        has_css?(".lovelace-member-checklist__countdown-bar") do |bar|
          bar.evaluate_script("this.getAnimations()[0].effect.getTiming().easing === 'steps(3)'")
        end
      end

      def has_fading_checklist?
        has_css?(".lovelace-member-checklist.--dismissing") do |widget|
          widget.evaluate_script(
            "Number(getComputedStyle(this).opacity) > 0 && Number(getComputedStyle(this).opacity) < 1",
          )
        end
      end

      def dismiss_completion_with_paused_clock
        page.driver.with_playwright_page do |browser|
          browser.get_by_role("button", name: "Dismiss", exact: true).dispatch_event("click")
          browser.clock.run_for(10)
        end
      end

      def advance_completion_clock(milliseconds)
        page.driver.with_playwright_page { |browser| browser.clock.run_for(milliseconds) }
      end

      def resume_completion_clock
        page.driver.with_playwright_page { |browser| browser.clock.resume }
      end

      def close_completion
        resume_completion_clock
        click_button("Dismiss", exact: true)
      end

      def has_completion_summary?
        has_celebration? && has_no_css?(".lovelace-member-checklist__items") &&
          has_button?("Dismiss", exact: true) && has_css?(".lovelace-member-checklist__close:focus")
      end

      def has_confetti?
        has_css?(".lovelace-member-checklist__confetti")
      end

      def has_no_confetti?
        has_no_css?(".lovelace-member-checklist__confetti")
      end

      def has_celebration?
        has_css?(
          ".lovelace-member-checklist__celebration",
          text: I18n.t("js.lovelace.member.complete"),
        )
      end

      def has_aligned_celebration?
        has_css?(".lovelace-member-checklist__celebration") do |message|
          message.evaluate_script(<<~JS)
            (() => {
              const title = document.querySelector('.lovelace-member-checklist__header h2').getBoundingClientRect();
              const padding = parseFloat(getComputedStyle(this).paddingInlineStart);
              return padding > 0 && Math.abs(this.getBoundingClientRect().left + padding - title.left) < 2;
            })()
          JS
        end
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
