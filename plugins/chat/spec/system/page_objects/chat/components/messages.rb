# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Messages < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-messages-scroller"

        def initialize(context)
          @context = context
        end

        def component
          page.find(context)
        end

        def copy_link(message)
          find(message).secondary_action("copyLink")
        end

        def bookmark(message)
          find(message).bookmark
        end

        def copy_text(message)
          find(message).secondary_action("copyText")
        end

        def flag(message)
          find(message).secondary_action("flag")
        end

        def reply_to(message)
          find(message).secondary_action("reply")
        end

        def emoji(message, code)
          find(message).emoji(code)
        end

        def delete(message)
          find(message).secondary_action("delete")
        end

        def restore(message)
          find(message).expand
          find(message).secondary_action("restore")
        end

        def edit(message)
          find(message).secondary_action("edit")
        end

        def has_action?(action, **args)
          message = find(args)
          message.open_more_menu
          page.has_css?("[data-value='#{action}']")
        end

        def has_no_action?(action, **args)
          message = find(args)
          message.open_more_menu
          page.has_no_css?("[data-value='#{action}']")
        end

        def expand(**args)
          find(args).expand
        end

        def select(args)
          find(args).select
        end

        def shift_select(args)
          find(args).select(shift: true)
        end

        def find(args)
          if args.is_a?(Hash)
            message.find(**args)
          else
            message.find(id: args.id)
          end
        end

        def has_message?(**args)
          message.exists?(**args)
        end

        def has_no_message?(**args)
          message.does_not_exist?(**args)
        end

        def has_selected_messages?(*messages)
          messages.all? { |message| has_message?(id: message.id, selected: true) }
        end

        def has_deleted_messages?(*messages)
          messages.all? { |message| has_message?(id: message.id, deleted: 1) }
        end

        def has_deleted_message?(message, count: 1)
          has_message?(id: message.id, deleted: count)
        end

        private

        def message
          PageObjects::Components::Chat::Message.new("#{context} #{SELECTOR}")
        end
      end
    end
  end
end
