# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ComposerMessageDetails < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-composer-message-details"

        def initialize(context)
          @context = context
        end

        def component
          find(context)
        end

        def has_message?(**args)
          selectors = SELECTOR
          selectors += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selectors += "[data-action=\"#{args[:action]}\"]" if args[:action]
          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?
          predicate = component.send(selector_method, selectors)

          text_options = {}
          text_options[:text] = args[:text] if args[:text]
          text_options[:exact_text] = args[:exact_text] if args[:exact_text]
          if text_options.present?
            predicate &&=
              component.send(selector_method, "#{selectors} .chat-reply__excerpt", **text_options)
          end

          predicate
        end

        def has_no_message?(**args)
          has_message?(**args, does_not_exist: true)
        end

        def editing?(message)
          has_message?(id: message.id, action: :edit)
        end

        def replying_to?(message)
          has_message?(id: message.id, action: :reply)
        end

        def cancel_edit
          component.find(".cancel-message-action").click
        end
      end
    end
  end
end
