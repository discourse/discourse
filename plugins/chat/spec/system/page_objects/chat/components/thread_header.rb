# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ThreadHeader < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".c-navbar"

        def initialize(context)
          @context = context
        end

        def component
          find(context)
        end

        def has_content?(content)
          component.find(SELECTOR).has_content?(content)
        end

        def has_title_content?(content)
          component.find(SELECTOR + " .c-navbar__title").has_content?(content)
        end

        def open_settings
          component.find(SELECTOR + " .c-navbar__thread-settings-button").click
        end

        def has_no_settings_button?
          component.has_no_css?(SELECTOR + " .c-navbar__thread-settings-button")
        end
      end
    end
  end
end
