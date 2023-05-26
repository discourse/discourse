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

        def message_details
          @message_details ||= PageObjects::Components::Chat::ComposerMessageDetails.new(context)
        end

        def input
          find(context).find(SELECTOR).find(".chat-composer__input")
        end

        def value
          input.value
        end

        def reply_to_last_message_shortcut
          input.send_keys(%i[shift arrow_up])
        end

        def edit_last_message_shortcut
          input.send_keys(%i[arrow_up])
        end

        def open_emoji_picker
          find(context).find(SELECTOR).find(".chat-composer-button__btn.emoji").click
        end

        def editing_message?(message)
          value == message.message && message_details.editing_message?(message)
        end
      end
    end
  end
end
