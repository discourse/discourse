# frozen_string_literal: true

module PageObjects
  module Modals
    class ChatChannelCreate < PageObjects::Modals::Base
      def select_category(category)
        find(".category-chooser").click
        find(".category-row[data-value=\"#{category.id}\"]").click
      end

      def create_channel_hint
        find(".create-channel-hint")
      end

      def slug_input
        find(".create-channel-slug-input")
      end

      def has_create_hint?(content)
        create_channel_hint.has_content?(content)
      end

      def fill_name(name)
        fill_in("channel-name", with: name)
      end

      def fill_slug(slug)
        fill_in("channel-slug", with: slug)
      end

      def fill_description(description)
        fill_in("channel-description", with: description)
      end

      def has_name_prefilled?(name)
        has_field?("channel-name", with: name)
      end
    end
  end
end
