# frozen_string_literal: true

module PageObjects
  module Components
    class AdminOnboardingBanner < PageObjects::Components::Base
      def step_names
        browser_root
          .locator(".admin-onboarding-banner .onboarding-step")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map do |step|
            step.evaluate(
              "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
              arg: "id",
            )
          end
      end

      def visible?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-onboarding-banner").filter(visible: true),
        )
      end

      def not_visible?
        have_count(0).matches?(
          browser_root.locator(".admin-onboarding-banner").filter(visible: true),
        )
      end

      def close
        browser_root.locator(".admin-onboarding-banner .btn-close").filter(visible: true).click
      end

      def step(step_id)
        browser_root.locator("div##{step_id}").filter(visible: true)
      end

      def step_completed?(step_id)
        have_count(0).does_not_match?(
          browser_root.locator(
            "div##{step_id} .onboarding-step__checkbox > svg.--completed",
          ).filter(visible: true),
        )
      end

      def step_not_completed?(step_id)
        have_count(0).matches?(
          browser_root.locator(
            "div##{step_id} .onboarding-step__checkbox > svg.--completed",
          ).filter(visible: true),
        )
      end

      def click_step_action(step_id)
        browser_root
          .locator("div##{step_id} .onboarding-step__action .btn")
          .filter(visible: true)
          .click
      end
    end
  end
end
