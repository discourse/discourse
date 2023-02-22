# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def initialize
        @composer_component = PageObjects::Components::Composer.new
        @fast_edit_component = PageObjects::Components::FastEditor.new
      end

      def visit_topic(topic)
        page.visit "/t/#{topic.id}"
        self
      end

      def open_new_topic
        page.visit "/"
        find("button#create-topic").click
        self
      end

      def open_new_message
        page.visit "/new-message"
        self
      end

      def visit_topic_and_open_composer(topic)
        visit_topic(topic)
        click_reply_button
        self
      end

      def has_post_content?(post)
        post_by_number(post).has_content? post.raw
      end

      def has_post_number?(number)
        has_css?("#post_#{number}")
      end

      def post_by_number(post_or_number)
        post_or_number = post_or_number.is_a?(Post) ? post_or_number.post_number : post_or_number
        find(".topic-post:not(.staged) #post_#{post_or_number}")
      end

      def post_by_number_selector(post_number)
        ".topic-post:not(.staged) #post_#{post_number}"
      end

      def has_post_more_actions?(post)
        within post_by_number(post) do
          has_css?(".show-more-actions")
        end
      end

      def has_post_bookmarked?(post)
        within post_by_number(post) do
          has_css?(".bookmark.with-reminder.bookmarked")
        end
      end

      def expand_post_actions(post)
        post_by_number(post).find(".show-more-actions").click
      end

      def click_post_action_button(post, button)
        case button
        when :bookmark
          post_by_number(post).find(".bookmark.with-reminder").click
        end
      end

      def click_topic_footer_button(button)
        find_topic_footer_button(button).click
      end

      def has_topic_bookmarked?
        has_css?("#{topic_footer_button_id("bookmark")}.bookmarked", text: "Edit Bookmark")
      end

      def find_topic_footer_button(button)
        find(topic_footer_button_id(button))
      end

      def click_reply_button
        find(".topic-footer-main-buttons > .create").click
        has_expanded_composer?
      end

      def has_expanded_composer?
        has_css?("#reply-control.open")
      end

      def type_in_composer(input)
        @composer_component.type_content(input)
      end

      def fill_in_composer(input)
        @composer_component.fill_content(input)
      end

      def clear_composer
        @composer_component.clear_content
      end

      def has_composer_content?(content)
        @composer_component.has_content?(content)
      end

      def send_reply
        find("#reply-control .save-or-cancel .create").click
      end

      def fill_in_composer_title(title)
        @composer_component.fill_title(title)
      end

      def fast_edit_button
        find(".quote-button .quote-edit-label")
      end

      def click_fast_edit_button
        find(".quote-button .quote-edit-label").click
      end

      def fast_edit_input
        find("#fast-edit-input")
      end

      def select_text(selector, offset = 10)
        js = <<-JS
          const node = document.querySelector(arguments[0]).childNodes[0];
          const selection = window.getSelection();
          const range = document.createRange();
          range.selectNodeContents(node);
          range.setEnd(node, arguments[1]);
          selection.removeAllRanges();
          selection.addRange(range);
        JS
    
        page.execute_script(js, selector, offset)
      end

      private

      def topic_footer_button_id(button)
        "#topic-footer-button-#{button}"
      end
    end
  end
end
