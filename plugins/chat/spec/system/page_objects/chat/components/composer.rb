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

        def context_name
          context.include?("thread") ? "thread" : "channel"
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

        def fill_in(with:)
          if rich_editor?
            input.click
            input.send_keys([PLATFORM_KEY_MODIFIER, "a"], :backspace)
            input.send_keys(with) if with.present?
          else
            input.fill_in(with: with)
          end

          self
        end

        def rich_editor?
          component.has_css?(".chat-composer__input.ProseMirror", wait: 0)
        end

        def has_rich_editor?
          component.has_css?(".chat-composer__input.ProseMirror")
        end

        def has_markdown_editor?
          component.has_css?("textarea.chat-composer__input")
        end

        def value
          return input.value unless rich_editor?

          page.evaluate_script(
            "Discourse.lookup('service:chat-#{context_name}-composer').editor?.value",
          )
        end

        def has_value?(expected)
          return has_field?(input[:id], with: expected) unless rich_editor?

          try_until_success { expect(value).to match(expected) }
          true
        rescue RSpec::Expectations::ExpectationNotMetError
          false
        end

        def toggle_editor
          rich = rich_editor?
          component.find(".chat-composer-dropdown__trigger-btn").click
          find(".chat-composer-dropdown__action-btn.toggle-editor").click
          rich ? has_markdown_editor? : has_rich_editor?
          self
        end

        def reply_to_last_message_shortcut
          input.click
          input.send_keys(%i[shift up])
        end

        def edit_last_message_shortcut
          input.click
          input.send_keys(%i[up])
        end

        # The markdown editor inserts placeholder text for an empty selection;
        # the rich editor only toggles the mark, so type the same text there.
        def emphasized_text_shortcut
          input.click
          input.send_keys([PLATFORM_KEY_MODIFIER, "i"])
          input.send_keys(I18n.t("js.composer.italic_text")) if rich_editor?
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
          input.send_keys(I18n.t("js.composer.bold_text")) if rich_editor?
        end

        def open_emoji_picker
          find(context).find(SELECTOR).find(".chat-composer-button.--emoji").click
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

        def enter_shortcut
          input.send_keys(:enter)
        end

        def shift_enter_shortcut
          input.send_keys(%i[shift enter])
        end

        def meta_enter_shortcut
          input.send_keys([PLATFORM_KEY_MODIFIER, :enter])
        end
      end
    end
  end
end
