# frozen_string_literal: true

module PageObjects
  module Components
    class AdminOnboardingBanner < PageObjects::Components::Base
      def visible?
        has_css?(".admin-onboarding-banner")
      end

      def not_visible?
        has_no_css?(".admin-onboarding-banner")
      end

      def close
        find(".admin-onboarding-banner .btn-close").click
      end

      def step(step_id)
        find("div##{step_id}")
      end

      def step_completed?(step_id)
        has_css?("div##{step_id} .onboarding-step__checkbox > svg.--completed")
      end

      def step_not_completed?(step_id)
        has_no_css?("div##{step_id} .onboarding-step__checkbox > svg.--completed")
      end

      def click_step_action(step_id)
        find("div##{step_id} .onboarding-step__action .btn").click
      end
    end
  end
end
