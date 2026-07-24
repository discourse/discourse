# frozen_string_literal: true

module PageObjects
  module Modals
    class ChatChannelCreate < PageObjects::Modals::Base
      EMOJI_PICKER = PageObjects::Components::EmojiPicker.new

      def form
        @form ||= PageObjects::Components::FormKit.new(".chat-modal-create-channel__form")
      end

      def select_category(category)
        find(".category-chooser").click
        find(".category-row[data-value=\"#{category.id}\"]").click
      end

      def select_emoji(emoji)
        find(".form-kit__field-emoji .btn-emoji").click
        EMOJI_PICKER.search_emoji(emoji)
        EMOJI_PICKER.select_emoji(":#{emoji}:")
      end

      def reset_emoji
        find(".form-kit__field-emoji .edit-channel-clear-emoji").click
      end

      def create_channel_hint
        find(".chat-modal-create-channel__hint")
      end

      def slug_input
        find("[data-name='slug'] input")
      end

      def has_create_hint?(content)
        create_channel_hint.has_content?(content)
      end

      def has_threading_toggle?
        has_selector?("[data-name='threading_enabled']")
      end

      def toggle_auto_join
        find("[data-name='auto_join_users'] .form-kit__control-checkbox-label").click
      end

      def fill_name(name)
        form.field("name").fill_in(name)
      end

      def fill_slug(slug)
        form.field("slug").fill_in(slug)
      end

      def fill_description(description)
        form.field("description").fill_in(description)
      end

      def has_name_prefilled?(name)
        form.field("name").has_value?(name)
      end

      def closed?
        has_no_selector?(".chat-modal-create-channel")
      end
    end
  end
end
