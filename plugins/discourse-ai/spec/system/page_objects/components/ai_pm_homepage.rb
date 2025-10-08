# frozen_string_literal: true

module PageObjects
  module Components
    class AiPmHomepage < PageObjects::Components::Base
      HOMEPAGE_WRAPPER_CLASS = ".ai-bot-conversations__content-wrapper"

      def visit
        page.visit("/discourse-ai/ai-bot/conversations")
      end

      def input
        page.find("#ai-bot-conversations-input")
      end

      def submit
        page.find(".ai-conversation-submit").click
      end

      def has_too_short_dialog?
        page.find(
          ".dialog-content",
          text:
            I18n.t(
              "js.discourse_ai.ai_bot.conversations.min_input_length_message",
              count: SiteSetting.min_personal_message_post_length,
            ),
        )
      end

      def has_homepage?
        page.has_css?(HOMEPAGE_WRAPPER_CLASS)
      end

      def has_no_homepage?
        page.has_no_css?(HOMEPAGE_WRAPPER_CLASS)
      end

      def has_no_new_question_button?
        page.has_no_css?(".ai-new-question-button")
      end

      def has_new_question_button?
        sidebar = PageObjects::Components::NavigationMenu::Sidebar.new
        sidebar.has_css?(
          "button.ai-new-question-button",
          text: I18n.t("js.discourse_ai.ai_bot.conversations.new"),
        )
      end

      def click_new_question_button
        page.find(".ai-new-question-button").click
      end

      def click_fist_sidebar_conversation
        page.find(".sidebar-section-content a.sidebar-section-link").click
      end

      def persona_selector
        PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")
      end

      def llm_selector
        PageObjects::Components::SelectKit.new(".persona-llm-selector__llm-dropdown")
      end

      def has_sidebar_back_link?
        page.has_css?(".sidebar-sections__back-to-forum")
      end
    end
  end
end
