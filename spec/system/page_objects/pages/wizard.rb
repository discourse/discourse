# frozen_string_literal: true

module PageObjects
  module Pages
    class Wizard < PageObjects::Pages::Base
      def click_jump_in
        find(".jump-in").click
      end

      def go_to_next_step
        find(".wizard-container__button.next").click
      end

      def select_access_option(label)
        find(".wizard-container__radio-choice", text: label).click
      end
    end
  end
end
