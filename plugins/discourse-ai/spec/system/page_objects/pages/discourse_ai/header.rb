# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseAi
      class Header < ::PageObjects::Pages::Header
        def click_bot_button
          find("header .ai-bot-button").click
        end

        def has_icon_in_bot_button?(icon:)
          page.has_css?("header .ai-bot-button .d-icon-#{icon}")
        end
      end
    end
  end
end
