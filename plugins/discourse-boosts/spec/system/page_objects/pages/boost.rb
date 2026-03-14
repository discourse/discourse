# frozen_string_literal: true

module PageObjects
  module Pages
    class Boost < PageObjects::Pages::Base
      def click_post_menu_boost_button(post)
        find("#post_#{post.post_number} .post-action-menu__boost").click
        self
      end

      def fill_in_boost(text)
        editor = find(".discourse-boosts__input-container .discourse-boosts__input")
        editor.send_keys(text)
        self
      end

      def submit_boost
        find(".discourse-boosts__submit").click
        self
      end

      def has_boost?(post, cooked_content = nil)
        selector = "#post_#{post.post_number} .discourse-boosts .discourse-boosts__cooked"
        if cooked_content
          has_css?("#{selector} img.emoji[alt='#{cooked_content}']")
        else
          has_css?(selector)
        end
      end

      def click_boost_cooked(post)
        find("#post_#{post.post_number} .discourse-boosts button.discourse-boosts__cooked").click
        self
      end

      def click_delete_boost(post)
        find("#post_#{post.post_number} .discourse-boosts__delete").click
        self
      end

      def has_no_boosts?(post)
        has_no_css?("#post_#{post.post_number} .discourse-boosts")
      end

      def has_post_menu_boost_button?(post)
        has_css?("#post_#{post.post_number} .post-action-menu__boost")
      end

      def has_no_post_menu_boost_button?(post)
        has_no_css?("#post_#{post.post_number} .post-action-menu__boost")
      end

      def has_boosts_list_boost_button?(post)
        has_css?("#post_#{post.post_number} .discourse-boosts__add-btn")
      end

      def has_no_boosts_list_boost_button?(post)
        has_no_css?("#post_#{post.post_number} .discourse-boosts__add-btn")
      end
    end
  end
end
