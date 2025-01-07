# frozen_string_literal: true

module PageObjects
  module Components
    class TopicList < PageObjects::Components::Base
      TOPIC_LIST_BODY_SELECTOR = ".topic-list-body"
      TOPIC_LIST_ITEM_SELECTOR = "#{TOPIC_LIST_BODY_SELECTOR} .topic-list-item"

      def topic_list
        TOPIC_LIST_BODY_SELECTOR
      end

      def has_topics?(count: nil)
        if count.nil?
          page.has_css?(TOPIC_LIST_ITEM_SELECTOR)
        else
          page.has_css?(TOPIC_LIST_ITEM_SELECTOR, count: count)
        end
      end

      def has_no_topics?
        page.has_no_css?(TOPIC_LIST_ITEM_SELECTOR)
      end

      def has_topic?(topic)
        page.has_css?(topic_list_item_class(topic))
      end

      def has_no_topic?(topic)
        page.has_no_css?(topic_list_item_class(topic))
      end

      def has_highlighted_topic?(topic)
        page.has_css?("#{topic_list_item_class(topic)}.highlighted")
      end

      def has_topic_checkbox?(topic)
        page.has_css?("#{topic_list_item_class(topic)} input#bulk-select-#{topic.id}")
      end

      def has_closed_status?(topic)
        page.has_css?("#{topic_list_item_closed(topic)}")
      end

      def has_unread_badge?(topic)
        page.has_css?("#{topic_list_item_unread_badge(topic)}")
      end

      def has_no_unread_badge?(topic)
        page.has_no_css?("#{topic_list_item_unread_badge(topic)}")
      end

      def has_checkbox_selected_on_row?(n)
        page.has_css?("#{TOPIC_LIST_ITEM_SELECTOR}:nth-child(#{n}) input.bulk-select:checked")
      end

      def has_no_checkbox_selected_on_row?(n)
        page.has_no_css?("#{TOPIC_LIST_ITEM_SELECTOR}:nth-child(#{n}) input.bulk-select:checked")
      end

      def click_topic_checkbox(topic)
        find("#{topic_list_item_class(topic)} input#bulk-select-#{topic.id}").click
      end

      def visit_topic_with_title(title)
        find("#{TOPIC_LIST_BODY_SELECTOR} a", text: title).click
      end

      def visit_topic(topic)
        find("#{topic_list_item_class(topic)} a.raw-topic-link").click
      end

      def visit_topic_last_reply_via_keyboard(topic)
        find("#{topic_list_item_class(topic)} a.post-activity").native.send_keys(:return)
      end

      def visit_topic_first_reply_via_keyboard(topic)
        find("#{topic_list_item_class(topic)} button.posts-map").native.send_keys(:return)
        find("#topic-entrance button.jump-top").native.send_keys(:return)
      end

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_ITEM_SELECTOR}[data-topic-id='#{topic.id}']"
      end

      def had_new_topics_alert?
        page.has_css?(".show-more.has-topics")
      end

      def click_new_topics_alert
        find(".show-more.has-topics").click
      end

      private

      def topic_list_item_closed(topic)
        "#{topic_list_item_class(topic)} .topic-statuses .topic-status svg.d-icon-lock"
      end

      def topic_list_item_unread_badge(topic)
        "#{topic_list_item_class(topic)} .topic-post-badges .unread-posts"
      end
    end
  end
end
