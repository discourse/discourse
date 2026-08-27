# frozen_string_literal: true

module PageObjects
  module Components
    class AiDiscoveriesSearch < PageObjects::Components::Base
      ROOT_SELECTOR = ".welcome-banner__search-menu"
      INPUT_SELECTOR = "#{ROOT_SELECTOR} #welcome-banner-search-input"
      SEARCH_OPTION_SELECTOR = "#{ROOT_SELECTOR} .ai-discoveries-search-options__option.--search"
      ASK_OPTION_SELECTOR = "#{ROOT_SELECTOR} .ai-discoveries-search-options__option.--ask"

      def open
        find(INPUT_SELECTOR).click
        self
      end

      def fill_query(query)
        find(INPUT_SELECTOR).fill_in(with: query)
        self
      end

      def clear_query
        fill_query("")
      end

      def submit
        find(INPUT_SELECTOR).send_keys(:enter)
        self
      end

      def select_search
        find(SEARCH_OPTION_SELECTOR).click
        self
      end

      def select_ask
        find(ASK_OPTION_SELECTOR).click
        self
      end

      def select_recent_search(query)
        find(
          "#{ROOT_SELECTOR} .search-menu-assistant-item[data-usage='recent-search']",
          exact_text: query,
        ).click
        self
      end

      def has_search_selected?
        has_css?("#{SEARCH_OPTION_SELECTOR}.is-active")
      end

      def has_ask_selected?
        has_css?("#{ASK_OPTION_SELECTOR}.is-active")
      end

      def has_discovery?
        has_css?("#{ROOT_SELECTOR} .ai-discobot-discoveries")
      end

      def has_no_discovery?
        has_no_css?("#{ROOT_SELECTOR} .ai-discobot-discoveries")
      end

      def has_topic_result?(topic)
        has_css?("#{ROOT_SELECTOR} .search-result-topic", text: topic.title)
      end
    end
  end
end
