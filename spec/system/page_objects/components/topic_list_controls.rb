# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListControls < PageObjects::Components::Base
      def has_new?(count:)
        text =
          if count == 0
            I18n.t("js.filters.new.title")
          else
            I18n.t("js.filters.new.title_with_count", count: count)
          end

        has_css?(".nav-item_new", exact_text: text)
      end

      def has_unread?(count:)
        text =
          if count == 0
            I18n.t("js.filters.unread.title")
          else
            I18n.t("js.filters.unread.title_with_count", count: count)
          end

        has_css?(".nav-item_unread", exact_text: text)
      end

      def dismiss_unread(untrack: false)
        click_button("dismiss-topics-top")
        find(".dismiss-read-modal__stop-tracking").click if untrack
        click_button("dismiss-read-confirm")
        self
      end

      def dismiss_new
        click_button("dismiss-new-top")
        self
      end

      def click_latest
        find(".nav-item_latest").click
        self
      end
    end
  end
end
