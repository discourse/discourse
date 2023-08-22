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

        has_css?(".nav-item_new", text: text)
      end

      def has_unread?(count:)
        text =
          if count == 0
            I18n.t("js.filters.unread.title")
          else
            I18n.t("js.filters.unread.title_with_count", count: count)
          end

        has_css?(".nav-item_unread", text: text)
      end

      def dismiss_unread
        click_button("dismiss-topics-bottom")
        click_button("dismiss-read-confirm")
        self
      end

      def dismiss_new
        click_button("dismiss-new-bottom")
        self
      end
    end
  end
end
