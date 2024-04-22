# frozen_string_literal: true

module PageObjects
  module Pages
    class Wizard < PageObjects::Pages::Base
      def click_jump_in
        find(".jump-in").click
      end
    end
  end
end
