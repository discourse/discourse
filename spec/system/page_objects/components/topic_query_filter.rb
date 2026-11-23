# frozen_string_literal: true

module PageObjects
  module Components
    class TopicQueryFilter < PageObjects::Components::Base
      INPUT = ".topic-query-filter__filter-term"
      TOKEN = ".filter-navigation-token"

      # Replaces the whole query: existing tokens are pulled back into the
      # input with Backspace and cleared, so no intermediate query is submitted.
      def fill_in(text)
        switch_to_text
        input = page.find(INPUT)

        while page.has_css?(TOKEN, wait: 0)
          input.fill_in(with: "")
          input.send_keys(:backspace)
        end

        input.fill_in(with: "#{text}\n")
        page.send_keys(:enter)
      end

      def switch_to_text
        return if page.has_css?(INPUT, wait: 0)

        page.find(".filter-navigation-builder__add").click
        page.find(".filter-navigation-builder__edit-as-text .btn").click
        page.find(INPUT)
      end

      def add_filter(name, value)
        page.find(".filter-navigation-builder__add").click
        page.find(
          ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='#{name}:']",
        ).click
        page.find(".filter-navigation-token__editor-input").fill_in(with: value)
        page.find(
          ".filter-navigation-token__editor .filter-navigation__tip-item",
          text: value,
        ).click
      end

      def has_input_text?(text)
        page.has_field?(class: "topic-query-filter__filter-term", with: text)
      end

      # Matches the query rendered as tokens, e.g. after a page load.
      def has_query?(text)
        tokens = text.split

        page.has_css?(TOKEN, count: tokens.size) &&
          tokens.all? { |raw| page.has_css?("#{TOKEN}[data-token=#{raw.inspect}]") }
      end

      def has_token?(filter, text: nil)
        page.has_css?("#{TOKEN}[data-filter='#{filter}']", text: text)
      end

      def remove_token(filter)
        page.find("#{TOKEN}[data-filter='#{filter}'] .filter-navigation-token__remove").click
      end
    end
  end
end
