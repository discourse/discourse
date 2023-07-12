# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class MessageCreator < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-modal-new-message"

        def component
          find(SELECTOR)
        end

        def input
          component.find(".chat-message-creator__input")
        end

        def filter(query = "")
          input.fill_in(with: query)
        end

        def opened?
          page.has_css?(SELECTOR)
        end

        def closed?
          page.has_no_css?(SELECTOR)
        end

        def enter_shortcut
          input.send_keys(:enter)
        end

        def backspace_shortcut
          input.send_keys(:backspace)
        end

        def shift_enter_shortcut
          input.send_keys(:shift, :enter)
        end

        def click_cta
          component.find(".chat-message-creator__open-dm-btn").click
        end

        def arrow_left_shortcut
          input.send_keys(:arrow_left)
        end

        def arrow_right_shortcut
          input.send_keys(:arrow_right)
        end

        def arrow_down_shortcut
          input.send_keys(:arrow_down)
        end

        def arrow_up_shortcut
          input.send_keys(:arrow_up)
        end

        def listing?(chatable, **args)
          component.has_css?(build_row_selector(chatable, **args))
        end

        def not_listing?(chatable, **args)
          component.has_no_css?(build_row_selector(chatable, **args))
        end

        def selecting?(chatable, **args)
          component.has_css?(build_item_selector(chatable, **args))
        end

        def not_selecting?(chatable, **args)
          component.has_no_css?(build_item_selector(chatable, **args))
        end

        def click_item(chatable, **args)
          component.find(build_item_selector(chatable, **args)).click
        end

        def click_row(chatable, **args)
          component.find(build_row_selector(chatable, **args)).click
        end

        def shift_click_row(chatable, **args)
          component.find(build_row_selector(chatable, **args)).click(:shift)
        end

        def has_unread_row?(chatable, **args)
          unread_selector = build_row_selector(chatable, **args)
          unread_selector += " .unread-indicator"
          unread_selector += ".-urgent" if args[:urgent]
          unread_selector += ":not(.-urgent)" unless args[:urgent]
          component.has_css?(unread_selector)
        end

        def build_item_selector(chatable, **args)
          selector = ".chat-message-creator__selection-item"
          selector += content_selector(**args)
          selector += chatable_selector(chatable)
          selector
        end

        def build_row_selector(chatable, **args)
          selector = ".chat-message-creator__row"
          selector += content_selector(**args)
          selector += chatable_selector(chatable, **args)
          selector
        end

        def content_selector(**args)
          selector = ""
          selector = ".-disabled" if args[:disabled]
          selector = ".-selected" if args[:selected]
          selector = ":not(.-disabled)" if args[:enabled]
          if args[:active]
            selector += ".-active"
          elsif args[:inactive]
            selector += ":not(.-active)"
          end
          selector
        end

        def chatable_selector(chatable, **args)
          selector = ""
          if chatable.try(:category_channel?)
            selector += ".-channel"
            selector += "[data-id='c-#{chatable.id}']"
          elsif chatable.try(:direct_message_channel?)
            selector += ".-channel"
            selector += "[data-id='c-#{chatable.id}']"
          else
            selector += ".-user"
            selector += "[data-id='u-#{chatable.id}']"
          end
          selector
        end
      end
    end
  end
end
