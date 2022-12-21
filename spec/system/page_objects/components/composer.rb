# frozen_string_literal: true

module PageObjects
  module Components
    class Composer < PageObjects::Components::Base
      def open_new_topic
        visit("/latest")
        find("button#create-topic").click
        self
      end

      def open_composer_actions
        find(".composer-action-title .btn").click
        self
      end

      def fill_title(title)
        find("#reply-control #reply-title").fill_in(with: title)
        self
      end

      def fill_content(content)
        find("#reply-control .d-editor-input").fill_in(with: content)
        self
      end

      def select_action(action)
        find(action(action)).click
        self
      end

      def create
        find("#reply-control .btn-primary").click
      end

      def action(action_title)
        ".composer-action-title .select-kit-collection li[title='#{action_title}']"
      end

      def button_label
        find("#reply-control .btn-primary .d-button-label")
      end
    end
  end
end
