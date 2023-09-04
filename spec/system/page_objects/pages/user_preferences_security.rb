# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSecurity < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/security")
        self
      end

      def visit_second_factor(password)
        click_link(class: "btn-second-factor")

        find(".second-factor input#password").fill_in(with: password)
        find(".second-factor .btn-primary").click
      end
    end
  end
end
