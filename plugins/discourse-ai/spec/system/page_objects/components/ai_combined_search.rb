# frozen_string_literal: true

module PageObjects
  module Components
    class AiCombinedSearch < PageObjects::Components::Base
      def fill_query(query, header: false)
        input(header:).fill_in(with: query)
      end

      def submit(header: false)
        input(header:).send_keys(:enter)
      end

      def search(query, header: false)
        fill_query(query, header:)
        submit(header:)
      end

      def search_while_intent_pending(query)
        fill_query(query)
        # Capybara's Enter waits for AJAX, which would also wait for the held model.
        page.driver.with_browser_page { |browser_page| browser_page.keyboard.press("Enter") }
      end

      def wait_for_intent_reply
        wait_for_client
      end

      def open_header
        find("#search-button").click
        expect(page).to have_css("#icon-search-input")
      end

      def close_header
        input(header: true).send_keys(:escape)
        expect(page).to have_no_css("#icon-search-input")
      end

      def expect_query(query, header: false)
        expect(page).to have_field(
          header ? "icon-search-input" : "welcome-banner-search-input",
          with: query,
        )
      end

      def select_recent(query)
        input.click
        find(".search-menu-recent .search-menu-assistant-item", text: query).click
      end

      def expect_recent(*terms)
        slugs = ".search-menu-recent .search-item-slug"
        # the list can still change as each history arrives, so it is retried
        page.document.synchronize do
          shown = page.all(slugs, wait: false).map(&:text)
          raise Capybara::ExpectationNotMet, "recent searches: #{shown}" if shown != terms
        end
      end

      def expect_no_search
        expect(page).to have_no_css(".ai-search-tabs")
      end

      def expect_tab(kind, label: nil)
        expect(page).to have_css("#{tab(kind)}.is-active")
        expect(page).to have_css(tab(kind), text: label) if label
      end

      def expect_tab_label(kind, label)
        expect(page).to have_css(tab(kind), text: label)
      end

      def expect_no_tab(kind)
        expect(page).to have_css(".ai-search-tabs")
        expect(page).to have_no_css(tab(kind))
      end

      def select_tab(kind)
        find(tab(kind)).click
        expect_tab(kind)
      end

      def expect_counts(active:, counts:, empty: [])
        expect(page).to have_no_css("#{tab(active)} .ai-search-tabs__count")
        counts.each do |kind, count|
          expect(page).to have_css("#{tab(kind)} .ai-search-tabs__count", exact_text: count.to_s)
        end
        empty.each { |kind| expect(page).to have_css("#{tab(kind)}.--empty") }
      end

      def expect_topic_results(*topics, absent: [])
        topics.each do |topic|
          expect(page).to have_css(".search-menu .search-result-topic", text: topic.title)
        end
        absent.each do |topic|
          expect(page).to have_no_css(".search-menu .search-result-topic", text: topic.title)
        end
      end

      def open_topic(topic)
        find(".search-menu .search-result-topic a.search-link", text: topic.title).click
      end

      def show_more
        find(".search-menu__show-more a").click
      end

      def expect_no_keyword_matches
        expect(page).to have_css(".search-menu .no-results", text: "No keyword matches found.")
        expect(page).to have_no_text("No results found.")
      end

      def expect_answer_loading
        expect(page).to have_css(".ai-search-answer .d-skeleton")
      end

      def expect_streaming_answer(text)
        expect_answer(text)
        expect(page).to have_no_css(".ai-search-answer__more")
      end

      def expect_answer(text)
        expect(page).to have_css(".ai-search-answer__body .cooked", text:)
        expect(page).to have_no_css(".search-menu .search-result-topic")
      end

      def expect_related_topics(topics, follow_up: nil)
        expect(page).to have_css(".ai-search-answer__related-heading", text: "Related topics")
        expect(page).to have_css(".ai-search-answer__related-item", count: topics.size)
        within(".ai-search-answer__more") do
          topics.each do |topic|
            expect(page).to have_css(".ai-search-answer__related-link", text: topic.title)
          end
          expect(page).to have_css(".ai-search-answer__related-link", count: topics.size)
          if follow_up
            expect(page).to have_css(
              ".ai-search-answer__follow-up-input[placeholder='#{follow_up}']",
            )
          else
            expect(page).to have_no_css(".ai-search-answer__follow-up")
          end
        end
        expect(page).to have_no_css(".ai-search-answer__related-excerpt")
        expect(page).to have_no_css(".ai-search-answer__expand")
        expect(page).to have_no_text("Keywords")
      end

      def expect_related_metadata(topic, category:, replies:, date:)
        within(".ai-search-answer__related-link", text: topic.title) do
          expect(page).to have_css(".ai-search-topic-row__date", text: date)
          expect(page).to have_css(
            ".ai-search-topic-row__replies[title='#{replies} replies']",
            text: replies.to_s,
          )
          expect(page).to have_css(".ai-search-topic-row__category", text: category.name)
        end
      end

      def expect_no_semantic_notices
        expect(page).to have_no_css(".ai-quick-search-notice")
        expect(page).to have_no_css(".search-menu .ai-search-result")
      end

      def expect_empty_answer
        expect(page).to have_css(
          ".ai-search-answer__empty",
          text: "AI couldn’t find a clear answer.",
        )
        expect(page).to have_css("#{tab("ask")} .ai-search-tabs__empty .d-icon-ban")
      end

      def ask_community(query)
        find(".ai-search-answer__ask-community", text: "Ask the community.").click
        expect(page).to have_css("#reply-control.open")
        expect(page).to have_field("reply-title", with: query)
      end

      def expect_scope_note(category = nil)
        if category
          expect(page).to have_css(
            ".ai-search-answer__scope-note",
            text: "Nothing found in #{category.name}",
          )
        else
          expect(page).to have_no_css(".ai-search-answer__scope-note")
        end
      end

      def expect_centered_empty_answer
        expect_empty_answer
        try_until_success do
          offsets = page.evaluate_script(<<~JS)
            (() => {
              const box = document.querySelector(".ai-search-answer__body").getBoundingClientRect();
              const text = document.createRange();
              text.selectNodeContents(document.querySelector(".ai-search-answer__empty"));
              const rect = text.getBoundingClientRect();
              return [
                Math.round(rect.top - box.top - (box.bottom - rect.bottom)),
                Math.round(rect.left - box.left - (box.right - rect.right)),
              ];
            })()
          JS
          expect(offsets.map(&:abs)).to all(be <= 2)
        end
      end

      def expect_scrollable_results
        expect(page).to have_css(".ai-search-answer__more")
        try_until_success do
          scroll = page.evaluate_script(<<~JS)
            (() => {
              const list = document.querySelector(".search-menu .panel-body-contents");
              const panel = document.querySelector(".search-menu .menu-panel");
              list.scrollTop = 50;
              return {
                overflows: list.scrollHeight > list.clientHeight,
                scrolled: list.scrollTop > 0,
                fits: list.getBoundingClientRect().bottom <= panel.getBoundingClientRect().bottom + 1,
              };
            })()
          JS
          expect(scroll).to eq("overflows" => true, "scrolled" => true, "fits" => true)
        end
      end

      def watch_tab_widths
        page.execute_script(<<~JS)
          window.aiSearchPillWidths = {};
          window.aiSearchPillObserver = new MutationObserver(() => {
            document.querySelectorAll(".ai-search-tabs .ai-discoveries-search-options__option").forEach((pill) => {
              const kind = [...pill.classList].find((name) => name.startsWith("--") && name !== "--empty");
              (window.aiSearchPillWidths[kind] ??= new Set()).add(Math.round(pill.getBoundingClientRect().width));
            });
          });
          window.aiSearchPillObserver.observe(document.body, { subtree: true, childList: true, characterData: true });
        JS
      end

      def expect_stable_tab_widths
        widths = page.evaluate_script(<<~JS)
          (() => {
            window.aiSearchPillObserver.disconnect();
            return Object.fromEntries(Object.entries(window.aiSearchPillWidths).map(([kind, set]) => [kind, set.size]));
          })()
        JS
        expect(widths).not_to be_empty
        expect(widths.values).to all(eq(1))
      end

      def wait_for_channel(channel = "/discourse-ai/discoveries")
        # Publishing before the subscription knows its position would skip the update.
        try_until_success(timeout: 10) { expect(page.evaluate_script(<<~JS)).to eq(true) }
          MessageBus.callbacks.some(
            (callback) => callback.channel === #{channel.to_json} && callback.last_id !== -1
          )
        JS
      end

      def wait_for_answer_delivery(message_id)
        try_until_success { expect(page.evaluate_script(<<~JS)).to eq(true) }
            MessageBus.callbacks.some(
              (callback) => callback.channel === "/discourse-ai/discoveries" && callback.last_id >= #{message_id}
            )
          JS
        wait_for_client
      end

      def expect_references(*topics, modal: false)
        root = modal ? ".ai-search-references-modal " : ""
        topics.each do |topic|
          expect(page).to have_css("#{root}.ai-search-references__link", text: topic.title)
        end
      end

      def expect_no_reference(topic)
        expect(page).to have_no_css(".ai-search-references__link", text: topic.title)
      end

      def expect_reference_metadata(topic)
        within(".ai-search-references__link", text: topic.title) do
          expect(page).to have_css(".ai-search-topic-row__date")
          expect(page).to have_css(".ai-search-topic-row__replies")
        end
        expect(page).to have_no_css(".timeline-container")
        expect(page).to have_no_css(".ai-search-references-button")
      end

      def open_mobile_references
        find(".ai-search-references-button").click
      end

      def expect_standard_timeline
        expect(page).to have_css(".timeline-container")
        expect(page).to have_no_css(".ai-search-references")
      end

      private

      def wait_for_client
        page.driver.with_browser_page do |browser_page|
          browser_page.evaluate(
            "() => window.clientSettled(#{Capybara.default_max_wait_time * 1000})",
          )
        end
      end

      def input(header: false)
        find(header ? "#icon-search-input" : "#welcome-banner-search-input")
      end

      def tab(kind)
        ".ai-search-tabs .ai-discoveries-search-options__option.--#{kind}"
      end
    end
  end
end
