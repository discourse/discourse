# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def initialize
        @composer_component = PageObjects::Components::Composer.new
        @fast_edit_component = PageObjects::Components::FastEditor.new
        @topic_map_component = PageObjects::Components::TopicMap.new
        @private_message_map_component = PageObjects::Components::PrivateMessageMap.new
      end

      def visit_topic(topic, post_number: nil)
        url = "/t/#{topic.id}"
        url += "/#{post_number}" if post_number
        page.visit(url)
        self
      end

      def open_new_topic
        page.visit "/new-topic"
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

      def current_topic_id
        find("h1[data-topic-id]")["data-topic-id"]
      end

      def current_topic
        ::Topic.find(current_topic_id)
      end

      def has_topic_title?(text)
        has_css?("h1 .fancy-title", text: text)
      end

      def has_post_content?(post)
        post_by_number(post).has_content? post.raw
      end

      def has_post_number?(number)
        has_css?("#post_#{number}")
      end

      def post_by_number(post_or_number, wait: Capybara.default_max_wait_time)
        post_or_number = post_or_number.is_a?(Post) ? post_or_number.post_number : post_or_number
        find(".topic-post:not(.staged) #post_#{post_or_number}", wait: wait)
      end

      def post_by_number_selector(post_number)
        ".topic-post:not(.staged) #post_#{post_number}"
      end

      def has_post_more_actions?(post)
        within_post(post) { has_css?(".show-more-actions") }
      end

      def has_post_bookmarked?(post, with_reminder: false)
        is_post_bookmarked(post, bookmarked: true, with_reminder: with_reminder)
      end

      def has_no_post_bookmarked?(post, with_reminder: false)
        is_post_bookmarked(post, bookmarked: false, with_reminder: with_reminder)
      end

      def expand_post_actions(post)
        post_by_number(post).find(".show-more-actions").click
      end

      def click_post_action_button(post, button)
        case button
        when :bookmark
          within_post(post) { find(".bookmark").click }
        when :reply
          within_post(post) { find(".post-controls .reply").click }
        when :flag
          within_post(post) { find(".post-controls .create-flag").click }
        when :copy_link
          within_post(post) { find(".post-controls .post-action-menu__copy-link").click }
        when :edit
          within_post(post) { find(".post-controls .edit").click }
        end
      end

      def expand_post_admin_actions(post)
        within_post(post) { find(".show-post-admin-menu").click }
      end

      def click_post_admin_action_button(post, button)
        element_klass = "[data-content][data-identifier='admin-post-menu']"
        case button
        when :grant_badge
          element_klass += " .grant-badge"
        when :change_owner
          element_klass += " .change-owner"
        end

        find(element_klass).click
      end

      def click_topic_bookmark_button
        within_topic_footer_buttons { find(".bookmark-menu-trigger").click }
      end

      def has_topic_bookmarked?(topic)
        within_topic_footer_buttons do
          has_css?(".bookmark-menu-trigger.bookmarked", text: "Edit Bookmark")
        end
      end

      def has_no_bookmarks?(topic)
        within_topic_footer_buttons { has_no_css?(".bookmark-menu-trigger.bookmarked") }
      end

      def click_reply_button
        within_topic_footer_buttons { find(".create").click }
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

      def has_composer_popup_content?(content)
        @composer_component.has_popup_content?(content)
      end

      def send_reply(content = nil)
        fill_in_composer(content) if content
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
        @fast_edit_component.fast_edit_input
      end

      def copy_quote_button_selector
        ".quote-button .copy-quote"
      end

      def copy_quote_button
        find(copy_quote_button_selector)
      end

      def click_mention(post, mention)
        within_post(post) { find("a.mention-group", text: mention).click }
      end

      def click_footer_reply
        find("#topic-footer-buttons .btn-primary", text: "Reply").click
        self
      end

      def click_like_reaction_for(post)
        within_post(post) { find(".post-controls .actions .like").click }
      end

      def has_topic_map?
        @topic_map_component.is_visible?
      end

      def has_no_topic_map?
        @topic_map_component.is_not_visible?
      end

      def has_private_message_map?
        @private_message_map_component.is_visible?
      end

      def click_notifications_button
        find(".topic-notifications-button .select-kit-header").click
      end

      def click_admin_menu_button
        within_topic_footer_buttons { find(".topic-admin-menu-button").click }
      end

      def watch_topic
        click_notifications_button
        find('li[data-name="watching"]').click
      end

      def close_topic
        click_admin_menu_button
        find(".topic-admin-popup-menu ul.topic-admin-menu-topic li.topic-admin-close").click
      end

      def has_read_post?(post)
        post_by_number(post).has_css?(".read-state.read", visible: :all, wait: 3)
      end

      def has_suggested_topic?(topic)
        page.has_css?("#suggested-topics .topic-list-item[data-topic-id='#{topic.id}']")
      end

      def move_to_public_category(category)
        click_admin_menu_button
        find(".topic-admin-menu-content li.topic-admin-convert").click
        move_to_public_modal.find(".category-chooser").click
        find(".category-row[data-value=\"#{category.id}\"]").click
        move_to_public_modal.find(".btn-primary").click
      end

      def move_to_public_modal
        find(".modal.convert-to-public-topic")
      end

      def open_flag_topic_modal
        expect(page).to have_css(".flag-topic", wait: Capybara.default_max_wait_time * 3)
        find(".flag-topic").click
      end

      private

      def within_post(post)
        within(post_by_number(post)) { yield }
      end

      def within_topic_footer_buttons
        within("#topic-footer-buttons") { yield }
      end

      def is_post_bookmarked(post, bookmarked:, with_reminder: false)
        within_post(post) do
          css_class = ".bookmark.bookmarked#{with_reminder ? ".with-reminder" : ""}"
          page.public_send(bookmarked ? :has_css? : :has_no_css?, css_class)
        end
      end
    end
  end
end
