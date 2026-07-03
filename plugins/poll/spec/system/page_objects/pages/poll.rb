# frozen_string_literal: true

module PageObjects
  module Pages
    class Poll < PageObjects::Pages::Base
      def initialize(topic_page: nil)
        @topic_page = topic_page || PageObjects::Pages::Topic.new
      end

      def has_poll_for_post?(post)
        @topic_page.post_by_number(post.post_number).has_css?(".poll")
      end

      def find_poll_for_post(post)
        @topic_page.post_by_number(post.post_number).find(".poll")
      end

      def has_option?(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_css?(".poll .option-text", text: option)
      end

      def has_no_option?(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_no_css?(".poll .option-text", text: option)
      end

      def vote_for_option(post, option)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.find("li[data-poll-option-id] button", text: option).click
      end

      def has_vote_count?(post, count)
        post_element = @topic_page.post_by_number(post.post_number)
        post_element.has_css?(".poll .info-number", text: count.to_s)
      end

      def click_cast_votes(post)
        @topic_page.post_by_number(post.post_number).find(".poll-buttons .cast-votes").click
      end

      def has_results_toggle?(post)
        @topic_page.post_by_number(post.post_number).has_css?(".poll-buttons button.toggle-results")
      end

      def scroll_results_toggle_into_view
        button = find(".poll-buttons button.toggle-results")
        page.execute_script("arguments[0].scrollIntoView({ block: 'center' });", button)
      end

      def click_results_toggle
        page.execute_script(
          "document.querySelector('.poll-buttons button.toggle-results').click();",
        )
      end

      def has_voting_options?(post)
        @topic_page.post_by_number(post.post_number).has_css?(".poll ul.options")
      end

      def has_poll_within_viewport?
        try_until_success { expect(poll_within_viewport?).to eq(true) }
        true
      rescue RSpec::Expectations::ExpectationNotMetError
        false
      end

      private

      def poll_within_viewport?
        page.evaluate_script(<<~JS)
          (() => {
            const rect = document.querySelector(".poll")?.getBoundingClientRect();
            return rect ? rect.top < window.innerHeight && rect.bottom > 0 : false;
          })()
        JS
      end
    end
  end
end
