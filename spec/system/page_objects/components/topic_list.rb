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
          have_count(0).does_not_match?(
            browser_root.locator(TOPIC_LIST_ITEM_SELECTOR).filter(visible: true),
          )
        else
          have_count(count).matches?(
            browser_root.locator(TOPIC_LIST_ITEM_SELECTOR).filter(visible: true),
          )
        end
      end

      def has_no_topics?
        have_count(0).matches?(browser_root.locator(TOPIC_LIST_ITEM_SELECTOR).filter(visible: true))
      end

      def has_topic?(topic)
        have_count(0).does_not_match?(
          browser_root.locator(topic_list_item_class(topic)).filter(visible: true),
        )
      end

      def has_no_topic?(topic)
        have_count(0).matches?(
          browser_root.locator(topic_list_item_class(topic)).filter(visible: true),
        )
      end

      def has_highlighted_topic?(topic)
        have_count(0).does_not_match?(
          browser_root.locator("#{topic_list_item_class(topic)}[data-test-was-highlighted]").filter(
            visible: true,
          ),
        )
      end

      def has_topic_checkbox?(topic)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} input#bulk-select-#{topic.id}",
          ).filter(visible: true),
        )
      end

      def has_no_topic_checkbox?(topic)
        have_count(0).matches?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} input#bulk-select-#{topic.id}",
          ).filter(visible: true),
        )
      end

      def has_bulk_select_enabled?
        have_count(0).does_not_match?(
          browser_root.locator("#{TOPIC_LIST_ITEM_SELECTOR} input.bulk-select").filter(
            visible: true,
          ),
        )
      end

      def has_closed_status?(topic)
        have_count(0).does_not_match?(
          browser_root.locator("#{topic_list_item_closed(topic)}").filter(visible: true),
        )
      end

      def has_unread_badge?(topic)
        have_count(0).does_not_match?(
          browser_root.locator("#{topic_list_item_unread_badge(topic)}").filter(visible: true),
        )
      end

      def has_no_unread_badge?(topic)
        have_count(0).matches?(
          browser_root.locator("#{topic_list_item_unread_badge(topic)}").filter(visible: true),
        )
      end

      def has_new_replies_dot?(topic)
        have_count(0).does_not_match?(
          browser_root.locator("#{topic_list_item_new_replies_dot(topic)}").filter(visible: true),
        )
      end

      def has_no_new_replies_dot?(topic)
        have_count(0).matches?(
          browser_root.locator("#{topic_list_item_new_replies_dot(topic)}").filter(visible: true),
        )
      end

      def has_checkbox_selected_on_row?(n)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{TOPIC_LIST_ITEM_SELECTOR}:nth-child(#{n}) input.bulk-select:checked",
          ).filter(visible: true),
        )
      end

      def has_no_checkbox_selected_on_row?(n)
        have_count(0).matches?(
          browser_root.locator(
            "#{TOPIC_LIST_ITEM_SELECTOR}:nth-child(#{n}) input.bulk-select:checked",
          ).filter(visible: true),
        )
      end

      def click_topic_checkbox(topic)
        browser_root
          .locator("#{topic_list_item_class(topic)} input#bulk-select-#{topic.id}")
          .filter(visible: true)
          .click
      end

      def click_topic_title(topic)
        browser_root
          .locator("#{topic_list_item_class(topic)} .raw-topic-link")
          .filter(visible: true)
          .click
      end

      def visit_topic_with_title(title)
        browser_root
          .locator("#{TOPIC_LIST_BODY_SELECTOR} a")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(title))
          .click
      end

      def visit_topic(topic)
        browser_root
          .locator("#{topic_list_item_class(topic)} a.raw-topic-link")
          .filter(visible: true)
          .click
      end

      def scroll_to_topic_at_index(index)
        browser_root
          .locator(TOPIC_LIST_ITEM_SELECTOR)
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all[
          index
        ].evaluate("element => element.scrollIntoView({block: 'start'})")
      end

      def scroll_page_down(amount: 50)
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: browser_arguments(amount))
          const listArea = document.querySelector("#list-area");
          if (!listArea) {
            throw new Error("Topic list area not found");
          }

          listArea.style.minHeight = "3000px";
          window.scrollTo(0, arguments[0]);
        JS
      end

      def scrolled_down?
        browser_page.evaluate("function(arguments) { return window.scrollY }", arg: []).positive?
      end

      def visit_topic_last_reply_via_keyboard(topic)
        browser_root
          .locator("#{topic_list_item_class(topic)} a.post-activity")
          .filter(visible: true)
          .press("Enter")
      end

      def visit_topic_first_reply_via_keyboard(topic)
        browser_root
          .locator("#{topic_list_item_class(topic)} a.badge-posts")
          .filter(visible: true)
          .press("Enter")
      end

      def send_keys_to_topic(topic, *keys)
        browser_root
          .locator("#{topic_list_item_class(topic)} a.raw-topic-link")
          .filter(visible: true)
          .press(browser_key_chord(keys))
      end

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_ITEM_SELECTOR}[data-topic-id='#{topic.id}']"
      end

      def topic(topic)
        browser_root.locator(topic_list_item_class(topic)).filter(visible: true)
      end

      def has_topic_tag?(topic, tag_name)
        contain_text([browser_text_pattern(tag_name)], useInnerText: true).matches?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} .discourse-tags .discourse-tag",
          ).filter(visible: true),
        )
      end

      def has_no_topic_tag?(topic, tag_name)
        contain_text([browser_text_pattern(tag_name)], useInnerText: true).does_not_match?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} .discourse-tags .discourse-tag",
          ).filter(visible: true),
        )
      end

      def has_topic_tags?(topic, tags:)
        tags.all? { |tag| has_topic_tag?(topic, tag.name) } &&
          have_count(tags.size).matches?(
            browser_root.locator(
              "#{topic_list_item_class(topic)} .discourse-tags .discourse-tag",
            ).filter(visible: true),
          )
      end

      def has_no_topic_tags?(topic)
        have_count(0).matches?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} .discourse-tags .discourse-tag",
          ).filter(visible: true),
        )
      end

      def click_topic_tag(topic, tag_name)
        browser_root
          .locator("#{topic_list_item_class(topic)} .discourse-tags .discourse-tag")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(tag_name))
          .click
      end

      def had_new_topics_alert?
        have_count(0).does_not_match?(
          browser_root.locator(".show-more.has-topics").filter(visible: true),
        )
      end

      def click_new_topics_alert
        browser_root.locator(".show-more.has-topics").filter(visible: true).click
      end

      def has_pinned_status?(topic)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} .topic-statuses .topic-status.--pinned",
          ).filter(visible: true),
        )
      end

      def has_no_pinned_status?(topic)
        have_count(0).matches?(
          browser_root.locator(
            "#{topic_list_item_class(topic)} .topic-statuses .topic-status.--pinned",
          ).filter(visible: true),
        )
      end

      private

      def topic_list_item_closed(topic)
        "#{topic_list_item_class(topic)} .topic-statuses .topic-status svg[class*='d-icon-lock']"
      end

      def topic_list_item_unread_badge(topic)
        "#{topic_list_item_class(topic)} .topic-post-badges .unread-posts"
      end

      def topic_list_item_new_replies_dot(topic)
        "#{topic_list_item_class(topic)} .topic-post-badges .new-replies"
      end
    end
  end
end
