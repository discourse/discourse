# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class SelectionManagement < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-selection-management"

        def initialize(context)
          @context = context
        end

        def visible?
          find(context).has_css?(SELECTOR)
        end

        def not_visible?
          find(context).has_no_css?(SELECTOR)
        end

        def has_no_move_action?
          has_no_button?(selector_for("move"))
        end

        def has_move_action?
          has_button?(selector_for("move"))
        end

        def component
          find(context).find(SELECTOR)
        end

        def cancel
          click_button("cancel")
        end

        def quote
          click_button("quote")
        end

        def copy
          click_button("copy")
        end

        def move
          click_button("move")
        end

        private

        def selector_for(action)
          case action
          when "quote"
            "chat-quote-btn"
          when "copy"
            "chat-copy-btn"
          when "cancel"
            "chat-cancel-selection-btn"
          when "move"
            "chat-move-to-channel-btn"
          end
        end

        def click_button(action)
          find_button(selector_for(action), disabled: false).click
        end
      end
    end
  end
end
