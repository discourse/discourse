# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannelSettings < PageObjects::Pages::Base
      def channel_form
        PageObjects::Components::FormKit.new(".c-channel-settings__channel-form")
      end

      def notification_form
        PageObjects::Components::FormKit.new(".c-channel-settings__notification-form")
      end

      def select_emoji(value)
        within(".c-channel-settings__channel-form .form-kit__field[data-name='emoji']") do
          find(".btn-emoji").click
        end
        PageObjects::Components::EmojiPicker.new.select_emoji(":#{value}:")
        self
      end

      def reset_emoji
        find(".c-channel-settings__channel-form .edit-channel-clear-emoji").click
        self
      end

      def has_slug?(slug)
        page.has_css?(".c-channel-settings__slug", text: slug)
      end

      def has_name?(name)
        page.has_css?(".c-channel-settings__name", text: name)
      end

      def has_open_button?(disabled: false)
        if disabled
          page.has_css?(".open-btn[disabled]")
        else
          page.has_css?(".open-btn:not([disabled])")
        end
      end

      def has_no_open_button?
        page.has_no_css?(".open-btn")
      end

      def has_close_button?
        page.has_css?(".close-btn")
      end

      def has_no_close_button?
        page.has_no_css?(".close-btn")
      end

      def hover_open_button
        find(".open-btn").hover
        self
      end
    end
  end
end
