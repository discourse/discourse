# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Composer < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-composer__wrapper"

        def initialize(context)
          @context = context
        end

        def blank?
          has_value?("")
        end

        def enabled?
          component.has_css?(".chat-composer.is-enabled")
        end

        def has_saved_draft?
          component.has_css?(".chat-composer.is-draft-saved")
        end

        def has_unsaved_draft?
          component.has_css?(".chat-composer.is-draft-unsaved")
        end

        def message_details
          @message_details ||= PageObjects::Components::Chat::ComposerMessageDetails.new(context)
        end

        def input
          component.find(".chat-composer__input")
        end

        def component
          find(context).find(SELECTOR)
        end

        def fill_in(**args)
          input.fill_in(**args)
        end

        def value
          input.value
        end

        def has_value?(expected)
          has_field?(input[:id], with: expected)
        end

        def reply_to_last_message_shortcut
          input.click
          input.send_keys(%i[shift arrow_up])
        end

        def edit_last_message_shortcut
          input.click
          input.send_keys(%i[arrow_up])
        end

        def emphasized_text_shortcut
          input.click
          input.send_keys([PLATFORM_KEY_MODIFIER, "i"])
        end

        def cancel_shortcut
          input.click
          input.send_keys(:escape)
        end

        def indented_text_shortcut
          input.click
          input.send_keys([PLATFORM_KEY_MODIFIER, "e"])
        end

        def bold_text_shortcut
          input.click
          input.send_keys([PLATFORM_KEY_MODIFIER, "b"])
        end

        def open_emoji_picker
          find(context).find(SELECTOR).find(".chat-composer-button.-emoji").click
        end

        def cancel_editing
          component.click_button(class: "cancel-message-action")
        end

        def editing_message?(message)
          has_value?(message.message) && message_details.editing?(message)
        end

        def editing_no_message?
          blank? && message_details.has_no_message?
        end

        def focus
          component.click
        end

        def focused?
          component.has_css?(".chat-composer.is-focused")
        end
      end
    end
  end
end
