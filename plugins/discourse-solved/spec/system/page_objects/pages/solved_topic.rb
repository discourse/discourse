# frozen_string_literal: true

module PageObjects
  module Pages
    class SolvedTopic < PageObjects::Pages::Topic
      UNACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-unaccepted"
      ACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-accepted"
      ACCEPTED_ANSWER_SELECTOR = ".accepted-answers .d-post-accordion-item"
      ACCEPTED_ANSWER_CONTENT_SELECTOR = ".d-post-accordion-item__content"
      SOLVER_SELECTOR = ".d-post-accordion-item__metadata .user-link"
      ACCEPTER_SELECTOR = ".d-post-accordion-item__metadata .accepter-link"
      QUOTE_TOGGLE_SELECTOR = ".d-post-accordion-item__toggle"

      def visit_solution(topic:, post:)
        visit_topic(topic, post_number: post.post_number)
      end

      def accept_solution(post)
        within_post(post) { find(UNACCEPTED_BUTTON_SELECTOR).click }
        self
      end

      def unaccept_solution(post)
        within_post(post) { find(ACCEPTED_BUTTON_SELECTOR).click }
        self
      end

      def has_accepted_solution?(post)
        within_post(post) { has_css?(ACCEPTED_BUTTON_SELECTOR) } &&
          has_css?(accepted_answer_selector(post))
      end

      def has_unaccepted_solution?(post)
        within_post(post) { has_css?(UNACCEPTED_BUTTON_SELECTOR) }
      end

      def has_solution_content?(post, content:)
        has_css?(
          "#{accepted_answer_selector(post)} #{ACCEPTED_ANSWER_CONTENT_SELECTOR}",
          text: content,
        )
      end

      def has_no_solution_content?(post)
        has_no_css?("#{accepted_answer_selector(post)} #{ACCEPTED_ANSWER_CONTENT_SELECTOR}")
      end

      def has_solution_authors?(post:, solver:, accepter:)
        within(accepted_answer_selector(post)) do
          has_css?(SOLVER_SELECTOR, text: solver.username) &&
            has_css?(ACCEPTER_SELECTOR, text: accepter.username)
        end
      end

      def has_solution_info?
        has_css?(ACCEPTED_ANSWER_SELECTOR) && has_css?(SOLVER_SELECTOR) &&
          has_css?(ACCEPTER_SELECTOR)
      end

      def has_no_solution_info?
        has_no_css?(ACCEPTED_ANSWER_SELECTOR) && has_no_css?(SOLVER_SELECTOR) &&
          has_no_css?(ACCEPTER_SELECTOR)
      end

      def toggle_solution_excerpt(post)
        within(accepted_answer_selector(post)) { find(QUOTE_TOGGLE_SELECTOR).click }
        self
      end

      def has_expanded_solution_excerpt?(post)
        has_css?("#{accepted_answer_selector(post)}[data-expanded]")
      end

      def has_collapsed_solution_excerpt?(post)
        has_css?("#{accepted_answer_selector(post)}:not([data-expanded])")
      end

      private

      def accepted_answer_selector(post)
        "#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post.post_number}']"
      end
    end
  end
end
