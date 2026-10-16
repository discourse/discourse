# frozen_string_literal: true

module PageObjects
  module Components
    class Post < PageObjects::Components::Base
      def initialize(post_number)
        @post_number = post_number
      end

      def post
        browser_root.locator(post_id).filter(visible: true)
      end

      def reply
        post.locator(".reply.create").filter(visible: true).click
      end

      def edit
        post.locator(".show-more-actions").filter(visible: true).click
        post.locator("button.edit").filter(visible: true).click
      end

      def show_replies
        post.locator(".show-replies").filter(visible: true).click
      end

      def jump_to_reply(reply)
        browser_root
          .locator(
            "#embedded-posts__bottom--#{@post_number} .reply[data-post-id='#{reply.id}'] a.post-info.arrow",
          )
          .filter(visible: true)
          .click
      end

      def load_more_replies
        browser_root
          .locator("#embedded-posts__bottom--#{@post_number} .load-more-replies")
          .filter(visible: true)
          .click
      end

      def cooked_content
        post.locator(".contents > .cooked").filter(visible: true)
      end

      def click_category_hashtag(category)
        post
          .locator("a.hashtag-cooked[data-type='category'][data-id='#{category.id}']")
          .filter(visible: true)
          .click
      end

      def has_cooked_content?(value)
        contain_text(browser_text_pattern(value), useInnerText: true).matches?(cooked_content)
      end

      def has_replies?(count: nil)
        have_count(count).matches?(
          browser_root
            .locator("#embedded-posts__bottom--#{@post_number}")
            .filter(visible: true)
            .locator(".reply")
            .filter(visible: true),
        )
      end

      def has_more_replies?
        have_count(0).does_not_match?(
          browser_root
            .locator("#embedded-posts__bottom--#{@post_number}")
            .filter(visible: true)
            .locator(".load-more-replies")
            .filter(visible: true),
        )
      end

      def has_loaded_all_replies?
        have_count(0).matches?(
          browser_root
            .locator("#embedded-posts__bottom--#{@post_number}")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".load-more-replies")
            .filter(visible: true),
        )
      end

      def visible?
        have_count(0).does_not_match?(browser_root.locator(post_id).filter(visible: true))
      end

      def show_parent_posts
        post.locator(".reply-to-tab").filter(visible: true).click
      end

      def has_parent_posts?(count: nil)
        have_count(count).matches?(
          browser_root
            .locator("#embedded-posts__top--#{@post_number}")
            .filter(visible: true)
            .locator(".reply")
            .filter(visible: true),
        )
      end

      def has_no_parent_post_content?(content)
        contain_text(browser_text_pattern(content), useInnerText: true).does_not_match?(
          browser_root
            .locator("#embedded-posts__top--#{@post_number}")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end,
        )
      end

      def post_language
        post.locator(".post-info.post-language").filter(visible: true).hover
        browser_root.locator(".post-language-content").filter(visible: true)
      end

      def toggle_localized_content
        post.locator(".post-info.post-language .fk-d-tooltip__trigger").filter(visible: true).click
        self
      end

      def open_post_history
        post.locator(".post-info.edits").filter(visible: true).click
      end

      def mentions_of(user)
        post
          .locator("a.mention[href='/u/#{user.username}']")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      private

      def post_id
        "#post_#{@post_number}"
      end
    end
  end
end
