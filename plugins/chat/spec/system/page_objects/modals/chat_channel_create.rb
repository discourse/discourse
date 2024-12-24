# frozen_string_literal: true

module PageObjects
  module Modals
    class ChatChannelCreate < PageObjects::Modals::Base
      def select_category(category)
        find(".category-chooser").click
        find(".category-row[data-value=\"#{category.id}\"]").click
      end

      def create_channel_hint
        find(".chat-modal-create-channel__hint")
      end

      def slug_input
        find(".-slug .chat-modal-create-channel__input")
      end

      def has_create_hint?(content)
        create_channel_hint.has_content?(content)
      end

      def has_threading_toggle?
        has_selector?(".chat-modal-create-channel__control.-threading-toggle")
      end

      def fill_name(name)
        fill_in("name", with: name)
      end

      def fill_slug(slug)
        fill_in("slug", with: slug)
      end

      def fill_description(description)
        fill_in("description", with: description)
      end

      def has_name_prefilled?(name)
        has_field?("name", with: name)
      end

      def closed?
        has_no_selector?(".chat-modal-create-channel")
      end
    end
  end
end
