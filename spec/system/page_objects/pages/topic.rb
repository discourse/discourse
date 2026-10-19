# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def initialize
        @composer_component = PageObjects::Components::Composer.new
        @fast_edit_component = PageObjects::Components::FastEditor.new
        @topic_map_component = PageObjects::Components::TopicMap.new
        @topic_timeline_component = PageObjects::Components::TopicTimeline.new
        @private_message_map_component = PageObjects::Components::PrivateMessageMap.new
      end

      def visit_topic(topic, post_number: nil)
        browser_page
          .goto(topic.url(post_number))
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def timeline
        @topic_timeline_component
      end

      def open_new_topic
        browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def open_new_message
        browser_page.goto("/new-message").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_topic_and_open_composer(topic)
        visit_topic(topic)
        click_reply_button
        self
      end

      def current_topic_id
        browser_root
          .locator("h1[data-topic-id]")
          .filter(visible: true)
          .get_attribute("data-topic-id")
      end

      def current_topic
        ::Topic.find(current_topic_id)
      end

      def topic_title
        browser_root.locator("#topic-title .fancy-title").filter(visible: true)
      end

      def has_topic_title?(text)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator("h1 .fancy-title").filter(visible: true),
        )
      end

      def has_topic_title_editor?
        have_count(0).does_not_match?(
          browser_root.locator("#topic-title input#edit-title").filter(visible: true),
        )
      end

      def has_no_topic_title_editor?
        have_count(0).matches?(
          browser_root.locator("#topic-title input#edit-title").filter(visible: true),
        )
      end

      def has_post_content?(post_number:, content:)
        contain_text(browser_text_pattern(content), useInnerText: true).matches?(
          browser_root.locator(post_by_number_selector(post_number)).filter(visible: true),
        )
      end

      def has_deleted_post?(post)
        have_count(0).does_not_match?(
          browser_root.locator(".topic-post.deleted:has(#post_#{post.post_number})").filter(
            visible: true,
          ),
        )
      end

      def has_no_deleted_post?(post)
        have_count(0).matches?(
          browser_root.locator(".topic-post.deleted:has(#post_#{post.post_number})").filter(
            visible: true,
          ),
        )
      end

      def has_post_number?(number)
        have_count(0).does_not_match?(browser_root.locator("#post_#{number}").filter(visible: true))
      end

      def has_replies_expanded?(post)
        within_post(post) do
          have_count(0).does_not_match?(
            browser_root.locator(".embedded-posts").filter(visible: true),
          )
        end
      end

      def has_replies_collapsed?(post)
        within_post(post) do
          have_count(0).matches?(browser_root.locator(".embedded-posts").filter(visible: true))
        end
      end

      def post_by_number(post_or_number, wait: Capybara.default_max_wait_time)
        post_or_number = post_or_number.is_a?(Post) ? post_or_number.post_number : post_or_number
        browser_root.locator(".topic-post:not(.staged) #post_#{post_or_number}").filter(
          visible: true,
        )
      end

      def post_by_number_selector(post_number)
        ".topic-post:not(.staged) #post_#{post_number}"
      end

      def has_no_post_more_actions?(post)
        within_post(post) do
          have_count(0).matches?(browser_root.locator(".show-more-actions").filter(visible: true))
        end
      end

      def has_post_more_actions?(post)
        within_post(post) do
          have_count(0).does_not_match?(
            browser_root.locator(".show-more-actions").filter(visible: true),
          )
        end
      end

      def has_post_bookmarked?(post, with_reminder: false)
        is_post_bookmarked(post, bookmarked: true, with_reminder: with_reminder)
      end

      def has_no_post_bookmarked?(post, with_reminder: false)
        is_post_bookmarked(post, bookmarked: false, with_reminder: with_reminder)
      end

      def expand_post_actions(post)
        post_by_number(post).locator(".show-more-actions").filter(visible: true).click
      end

      def click_post_author_avatar(post)
        within_post(post) do
          browser_root
            .locator(".main-avatar[data-user-card='#{post.user.username}']")
            .filter(visible: true)
            .click
        end
      end

      def click_post_action_button(post, button)
        find_post_action_button(post, button).click
      end

      def open_post_translations(post)
        click_post_action_button(post, :show_more)
        click_post_action_button(post, :add_translation)
        browser_root.locator(".post-action-menu__view-translation").filter(visible: true).click
        self
      end

      def find_post_action_buttons(post)
        within_post(post) { browser_root.locator(".post-controls .actions").filter(visible: true) }
      end

      def find_post_action_button(post, button)
        button_selector = selector_for_post_action_button(button)
        within_post(post) { browser_root.locator(button_selector).filter(visible: true) }
      end

      def has_post_action_button?(post, button)
        button_selector = selector_for_post_action_button(button)
        within_post(post) do
          have_count(0).does_not_match?(browser_root.locator(button_selector).filter(visible: true))
        end
      end

      def has_no_post_action_button?(post, button)
        button_selector = selector_for_post_action_button(button)
        within_post(post) do
          have_count(0).matches?(browser_root.locator(button_selector).filter(visible: true))
        end
      end

      def has_who_liked_on_post?(post, count: nil)
        if count
          return(
            have_count(count).matches?(
              browser_root.locator(".users-popup .users-popup__item").filter(visible: true),
            )
          )
        end

        have_count(0).does_not_match?(browser_root.locator(".users-popup").filter(visible: true))
      end

      def has_no_who_liked_on_post?(post)
        have_count(0).matches?(browser_root.locator(".users-popup").filter(visible: true))
      end

      def has_who_read_on_post?(post, count: nil)
        if count
          return(
            within_post(post) do
              have_count(count).matches?(
                browser_root.locator(".who-read.--expanded a.trigger-user-card").filter(
                  visible: true,
                ),
              )
            end
          )
        end

        within_post(post) do
          have_count(0).does_not_match?(
            browser_root.locator(".who-read.--expanded").filter(visible: true),
          )
        end
      end

      def has_no_who_read_on_post?(post)
        within_post(post) do
          have_count(0).matches?(browser_root.locator(".who-read.--expanded").filter(visible: true))
        end
      end

      def expand_post_admin_actions(post)
        click_post_action_button(post, :admin)
      end

      def has_post_admin_menu?()
        have_count(0).does_not_match?(
          browser_root.locator("[data-content][data-identifier='admin-post-menu']").filter(
            visible: true,
          ),
        )
      end

      def has_no_post_admin_menu?()
        have_count(0).matches?(
          browser_root.locator("[data-content][data-identifier='admin-post-menu']").filter(
            visible: true,
          ),
        )
      end

      def click_post_admin_action_button(post, button)
        element_klass = "[data-content][data-identifier='admin-post-menu']"
        case button
        when :grant_badge
          element_klass += " .grant-badge"
        when :change_owner
          element_klass += " .change-owner"
        when :permanently_delete
          element_klass += " .permanently-delete"
        end

        browser_root.locator(element_klass).filter(visible: true).click
      end

      def permanently_delete_post(post)
        expand_post_actions(post)
        expand_post_admin_actions(post)
        click_post_admin_action_button(post, :permanently_delete)
      end

      def open_post_history(post)
        post_by_number(post).locator(".post-info.edits").filter(visible: true).click
      end

      def click_topic_bookmark_button
        within_topic_footer_buttons do
          browser_root.locator(".bookmark-menu-trigger").filter(visible: true).click
        end
      end

      def click_topic_edit_title
        browser_root.locator("#topic-title .fancy-title").filter(visible: true).click
      end

      def click_topic_title_submit_edit
        browser_root.locator("#topic-title .submit-edit").filter(visible: true).click
      end

      def click_topic_title_cancel_edit
        browser_root.locator("#topic-title .cancel-edit").filter(visible: true).click
      end

      def has_editing_localization_indicator?
        have_count(0).does_not_match?(
          browser_root.locator("#topic-title .editing-localization-indicator").filter(
            visible: true,
          ),
        )
      end

      def has_no_editing_localization_indicator?
        have_count(0).matches?(
          browser_root.locator("#topic-title .editing-localization-indicator").filter(
            visible: true,
          ),
        )
      end

      def has_topic_bookmarked?(topic)
        within_topic_footer_buttons do
          contain_text([browser_text_pattern("Edit bookmark")], useInnerText: true).matches?(
            browser_root.locator(".bookmark-menu-trigger.bookmarked").filter(visible: true),
          )
        end
      end

      def has_no_bookmarks?(topic)
        within_topic_footer_buttons do
          have_count(0).matches?(
            browser_root.locator(".bookmark-menu-trigger.bookmarked").filter(visible: true),
          )
        end
      end

      def has_topic_status_bookmark?
        have_count(0).does_not_match?(
          browser_root.locator("#topic-title .topic-status.--bookmarked").filter(visible: true),
        )
      end

      def has_no_topic_status_bookmark?
        have_count(0).matches?(
          browser_root.locator("#topic-title .topic-status.--bookmarked").filter(visible: true),
        )
      end

      def click_reply_button
        within_topic_footer_buttons { browser_root.locator(".create").filter(visible: true).click }
        has_expanded_composer?
      end

      def click_floating_reply_button
        browser_root.locator(".embed-floating-reply-button").filter(visible: true).click
      end

      def has_floating_reply_button?
        have_count(0).does_not_match?(
          browser_root.locator(".embed-floating-reply-button").filter(visible: true),
        )
      end

      def has_no_floating_reply_button?
        have_count(0).matches?(
          browser_root.locator(".embed-floating-reply-button").filter(visible: true),
        )
      end

      def click_floating_timeline_button
        browser_root.locator(".embed-floating-timeline-button").filter(visible: true).click
      end

      def has_floating_timeline_button?
        have_count(0).does_not_match?(
          browser_root.locator(".embed-floating-timeline-button").filter(visible: true),
        )
      end

      def has_no_floating_timeline_button?
        have_count(0).matches?(
          browser_root.locator(".embed-floating-timeline-button").filter(visible: true),
        )
      end

      def has_docked_composer?
        have_count(0).does_not_match?(
          browser_root.locator(".embed-mode-composer .docked-composer").filter(visible: true),
        )
      end

      def has_no_docked_composer?
        have_count(0).matches?(
          browser_root.locator(".embed-mode-composer .docked-composer").filter(visible: true),
        )
      end

      def click_embed_reply_button
        within_topic_footer_buttons { browser_root.locator(".create").filter(visible: true).click }
        self
      end

      def has_expanded_composer?
        have_count(0).does_not_match?(
          browser_root.locator("#reply-control.open").filter(visible: true),
        )
      end

      def composer
        @composer_component
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
        @composer_component.has_displayed_content?(content)
      end

      def has_composer_popup_content?(content)
        @composer_component.has_popup_content?(content)
      end

      def send_reply(content = nil)
        fill_in_composer(content) if content
        browser_root.locator("#reply-control .save-or-cancel .create").filter(visible: true).click
      end

      def fill_in_composer_title(title)
        @composer_component.fill_title(title)
      end

      def fast_edit_button
        browser_root.locator(".quote-button .quote-edit-label").filter(visible: true)
      end

      def click_fast_edit_button
        browser_root.locator(".quote-button .quote-edit-label").filter(visible: true).click
      end

      def fast_edit_input
        @fast_edit_component.fast_edit_input
      end

      def copy_quote_button_selector
        ".quote-button .copy-quote"
      end

      def copy_quote_button
        browser_root.locator(copy_quote_button_selector).filter(visible: true)
      end

      def click_mention(post, mention)
        within_post(post) do
          browser_root
            .locator("a.mention-group")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(mention))
            .click
        end
      end

      def click_footer_reply
        button =
          browser_root
            .locator("#topic-footer-buttons .btn-primary")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Reply"))
        browser_page.evaluate(
          "function(arguments) { arguments[0].scrollIntoView(); }",
          arg: browser_arguments(button),
        )
        button.click
        self
      end

      def click_like_reaction_for(post)
        post_container = post_container_for(post)

        if post_container
             .locator(".discourse-reactions-reaction-button")
             .filter(visible: true)
             .count != 0
          post_container.locator(".discourse-reactions-reaction-button").filter(visible: true).click
        else
          post_container.locator(".post-action-menu__like").filter(visible: true).click
        end
      end

      def has_like_count_for?(post, count)
        contain_text([browser_text_pattern(count.to_s)], useInnerText: true).matches?(
          post_container_for(post).locator(
            ".post-action-menu__like-count, .reactions-counter",
          ).filter(visible: true),
        )
      end

      def post_container_for(post)
        post_number = post.is_a?(Post) ? post.post_number : post
        post_by_number(post_number)
          .locator("xpath=ancestor::*")
          .and(browser_page.locator(".topic-post"))
          .last
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
        browser_root
          .locator(".topic-notifications-button .notifications-tracking-trigger")
          .filter(visible: true)
          .click
      end

      def click_admin_menu_button
        within_topic_footer_buttons do
          browser_root.locator(".toggle-admin-menu").filter(visible: true).click
        end
        PageObjects::Components::TopicAdminMenu.new
      end

      def watch_topic
        click_notifications_button
        browser_root
          .locator('.notifications-tracking-btn[data-level-name="watching"]')
          .filter(visible: true)
          .click
      end

      def close_topic
        click_admin_menu_button
        browser_root
          .locator(".topic-admin-popup-menu ul.topic-admin-menu-topic li.topic-admin-close")
          .filter(visible: true)
          .click
      end

      def has_read_post?(post)
        have_count(0, timeout: 3 * 1000).does_not_match?(
          post_by_number(post).locator(".read-state.read"),
        )
      end

      def has_suggested_topic?(topic)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#suggested-topics .topic-list-item[data-topic-id='#{topic.id}']",
          ).filter(visible: true),
        )
      end

      def move_to_public_category(category)
        click_admin_menu_button
        browser_root
          .locator(".topic-admin-menu-content li.topic-admin-convert")
          .filter(visible: true)
          .click
        move_to_public_modal.locator(".category-chooser").filter(visible: true).click
        browser_root
          .locator(".category-row[data-value=\"#{category.id}\"]")
          .filter(visible: true)
          .click
        move_to_public_modal.locator(".btn-primary").filter(visible: true).click
      end

      def move_to_public_modal
        browser_root.locator(".d-modal.convert-to-public-topic").filter(visible: true)
      end

      def has_no_flag_button?
        have_count(0).matches?(
          browser_root.locator(".post-action-menu__flag.create-flag").filter(visible: true),
        )
      end

      def open_flag_topic_modal
        expect(browser_root.locator(".flag-topic").filter(visible: true)).not_to have_count(
          0,
          timeout: (Capybara.default_max_wait_time * 3) * 1000,
        )
        browser_root.locator(".flag-topic").filter(visible: true).click
      end

      def within_post(post)
        within_browser(post_by_number(post)) { yield }
      end

      def has_filtered_notice_text?(text)
        contain_text(browser_text_pattern(text), useInnerText: true).matches?(
          browser_root.locator(".posts-filtered-notice").filter(visible: true),
        )
      end

      def topic_tags
        tags_selector = ".title-wrapper .topic-category .list-tags .discourse-tags .discourse-tag"
        browser_root
          .locator(tags_selector)
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      end

      def has_topic_tag?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".title-wrapper .discourse-tag").filter(visible: true),
        )
      end

      def has_content_language_preferences_launcher?
        have_count(0).does_not_match?(
          browser_root.locator(".topic-content-language-preferences").filter(visible: true),
        )
      end

      def has_no_topic_admin_menu?
        have_count(0).matches?(
          browser_root.locator(".topic-admin-menu-trigger").filter(visible: true),
        )
      end

      def open_content_language_preferences
        browser_root.locator(".topic-content-language-preferences").filter(visible: true).click
        PageObjects::Modals::ContentLanguagePreferences.new
      end

      private

      def within_topic_footer_buttons
        within_browser(browser_root.locator("#topic-footer-buttons").filter(visible: true)) do
          yield
        end
      end

      def selector_for_post_action_button(button)
        case button
        when :add_translation
          ".post-controls .post-action-menu-edit-translations-trigger"
        when :admin
          ".post-controls .post-action-menu__admin"
        when :bookmark
          ".post-controls .post-action-menu__bookmark"
        when :copy_link, :copyLink
          ".post-controls .post-action-menu__copy-link"
        when :delete
          ".post-controls .post-action-menu__delete"
        when :edit
          ".post-controls .post-action-menu__edit"
        when :flag
          ".post-controls .post-action-menu__flag"
        when :like
          ".post-controls .post-action-menu__like"
        when :like_count
          ".post-controls .post-action-menu__like-count"
        when :read
          ".post-controls .post-action-menu__read"
        when :recover
          ".post-controls .post-action-menu__recover"
        when :replies
          ".post-controls .post-action-menu__show-replies"
        when :reply
          ".post-controls .post-action-menu__reply"
        when :share
          ".post-controls .post-action-menu__share"
        when :show_more
          ".post-controls .post-action-menu__show-more"
        else
          raise "Unknown post menu button type: #{button}"
        end
      end

      def is_post_bookmarked(post, bookmarked:, with_reminder: false)
        within_post(post) do
          css_class = ".bookmark.bookmarked#{with_reminder ? ".with-reminder" : ""}"
          target = browser_root.locator(css_class).filter(visible: true)
          if bookmarked
            have_count(0).does_not_match?(target)
          else
            have_count(0).matches?(target)
          end
        end
      end
    end
  end
end
