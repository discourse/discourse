# frozen_string_literal: true

describe "AI combined search" do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:author, :user)
  fab!(:topic_1) { Fabricate(:topic, user: author, title: "Password resets and account recovery") }
  fab!(:topic_2) { Fabricate(:topic, user: author, title: "Login help for new members") }
  fab!(:llm_model, :fake_model)
  fab!(:ask_agent) { Fabricate(:ai_agent, allowed_group_ids: [Group::AUTO_GROUPS[:admins]]) }

  let(:query) { "how do I reset my password" }
  let(:requests) { [] }
  let(:search) { PageObjects::Components::AiCombinedSearch.new }
  let(:logo) { PageObjects::Components::Logo.new }
  let(:sources) do
    [topic_1, topic_2].map do |topic|
      { title: topic.title, url: topic.url, excerpt: "An excerpt about #{topic.title}" }
    end
  end

  before do
    enable_current_plugin
    SiteSetting.ai_default_llm_model = llm_model.id
    SiteSetting.ai_ask_ai_agent = ask_agent.id
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    SiteSetting.enable_ai_combined_search = true

    # Stream each answer phase from the spec rather than starting an LLM job.
    allow(DiscourseAi::Discoveries).to receive(
      :enqueue_reply,
    ) do |user:, query:, request_id:, scope: nil, trigger: "", trigger_reason: "", intent_heuristic: "", **|
      requests << { id: request_id, query:, scope:, trigger: [trigger, trigger_reason] }
      AskAiLog.create!(
        user:,
        query:,
        asked_at: Time.current,
        ask_intent_heuristic: intent_heuristic,
      )
    end

    sign_in(user)
  end

  def publish(payload)
    search.wait_for_channel
    MessageBus.publish(
      "/discourse-ai/discoveries",
      { query: requests.last.fetch(:query), request_id: requests.last.fetch(:id) }.merge(payload),
      user_ids: [user.id],
    )
  end

  def wait_for_request(term, after:)
    try_until_success do
      expect(requests.size).to eq(after + 1)
      expect(requests.last.fetch(:query)).to eq(term)
    end
  end

  def ask(term, header: false)
    previous_count = requests.size
    search.search(term, header:)
    wait_for_request(term, after: previous_count)
  end

  def expect_opening(term, tab:, reason:, **attributes)
    try_until_success do
      expect(AskAiLog.find_by(query: term)).to have_attributes(
        ask_tab_opened: tab,
        ask_tab_opened_reason: reason,
        **attributes,
      )
    end
  end

  def complete_answer(**overrides)
    publish(
      {
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_title: "Resetting your password",
        ai_discover_reply: "Use the **forgot password** link on the login screen.",
        ai_discover_follow_up: "What if I no longer have access to my email?",
        sources:,
      }.merge(overrides),
    )
  end

  def empty_answer(**overrides)
    complete_answer(answerable: false, ai_discover_reply: "", sources: [], **overrides)
  end

  # Verify opening reasons for every intent branch so searched_again cannot mask them.
  context "when reading a streamed answer" do
    fab!(:category) { Fabricate(:category, name: "Account help") }
    fab!(:more_topics) do
      Array.new(3) do |index|
        Fabricate(:topic, user: author, category:, title: "Account recovery guide part #{index}")
      end
    end
    fab!(:follow_up_agent) do
      Fabricate(:ai_agent, allowed_group_ids: [Group::AUTO_GROUPS[:admins]]).tap(&:create_user!)
    end

    it "lets the reader submit, read the full answer and scroll through all its sources" do
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      SiteSetting.ai_ask_ai_follow_up_agent = follow_up_agent.id
      page.current_window.resize_to(1400, 450)

      visit "/"
      search.fill_query(query)
      search.expect_no_search
      expect(requests).to be_empty
      ask(query)

      search.expect_tab("ask")
      expect_opening(query, tab: "ask", reason: "question")
      search.expect_answer_loading
      all_sources =
        sources +
          more_topics.map do |topic|
            {
              title: topic.title,
              url: topic.url,
              excerpt: "An excerpt about #{topic.title}",
              category_id: topic.category_id,
              topic_replies: 12,
              bumped_at: 2.days.ago.iso8601,
            }
          end
      publish(
        done: false,
        phase: "rewritten",
        keyword_query: "reset password",
        semantic_query: "How can I reset a forgotten password?",
      )
      publish(
        done: false,
        phase: "sources",
        ai_discover_title: "Resetting your password",
        sources: all_sources,
      )
      publish(done: false, phase: "answering", ai_discover_reply: "Use the **forgot")
      search.expect_streaming_answer("Use the")

      complete_answer(
        ai_discover_reply: "Use the **forgot password** link on the login screen. " * 40,
        sources: all_sources,
      )
      search.expect_answer("forgot password")
      search.expect_related_topics(
        [topic_1, topic_2, *more_topics],
        follow_up: "What if I no longer have access to my email?",
      )
      search.expect_related_metadata(more_topics.last, category:, replies: 12, date: "2d")
      search.expect_scrollable_results
    ensure
      page.current_window.resize_to(1400, 1400)
    end
  end

  it "lets a reader without bot access use foreign-language answers or ask the community when answers are empty" do
    visit "/"
    ask("сброс")

    search.expect_tab("ask")
    expect_opening("сброс", tab: "ask", reason: "language")
    expect(requests.last.fetch(:trigger)).to eq(["enter", ""])
    complete_answer
    search.expect_related_topics([topic_1, topic_2])

    term = "unheard of things"
    ask(term)

    search.expect_tab("ask")
    expect_opening(term, tab: "ask", reason: "no_keyword_matches")
    search.expect_counts(active: "ask", counts: { topics: 0 }, empty: ["topics"])
    search.select_tab("topics")
    search.expect_no_keyword_matches
    search.select_tab("ask")
    empty_answer
    search.expect_empty_answer
    search.expect_centered_empty_answer
    search.ask_community(term)
  end

  context "with keyword results" do
    let(:query) { "password" }

    fab!(:password_post) do
      Fabricate(
        :post,
        user: author,
        topic: topic_1,
        raw: "Reset your password from the login screen",
      )
    end

    before do
      SearchIndexer.enable
      SearchIndexer.index(topic_1, force: true)
    end

    after { SearchIndexer.disable }

    it "lets the reader switch between fetched tabs and open a keyword result without semantic notices" do
      SiteSetting.ai_embeddings_semantic_quick_search_enabled = true
      visit "/"
      ask(query)

      search.expect_tab("topics")
      search.expect_topic_results(topic_1)
      search.expect_counts(active: "topics", counts: {})
      search.select_tab("ask")
      search.expect_counts(active: "ask", counts: { topics: 1 })
      search.expect_answer_loading
      search.select_tab("topics")
      message_id = complete_answer(ai_discover_reply: "An answer.")
      search.wait_for_answer_delivery(message_id)
      search.expect_tab("topics")
      search.expect_topic_results(topic_1)
      search.expect_no_semantic_notices
      search.select_tab("ask")
      search.expect_answer("An answer.")
      search.select_tab("topics")
      expect(requests.size).to eq(1)
      expect_opening(
        query,
        tab: "topics",
        reason: "topic_results",
        ask_intent_heuristic: "lookup",
        ask_tab_switched_to: "ask",
      )

      search.open_topic(topic_1)
      try_until_success do
        expect(AskAiLog.find_by(query:)).to have_attributes(
          ask_tab_opened_after_ms: be >= 0,
          ask_result_clicked_tab: "topics",
          ask_result_clicked_after_ms: be > 0,
        )
      end
    end

    it "lets the reader reopen header results or go to full search with Enter or the more link" do
      6.times do |index|
        topic = Fabricate(:topic, user: author, title: "Widget maintenance guide number #{index}")
        Fabricate(
          :post,
          user: author,
          topic:,
          raw: "Keeping widgets running smoothly, part #{index}",
        )
        SearchIndexer.index(topic, force: true)
      end
      visit "/about"
      search.open_header
      ask(query, header: true)
      search.expect_topic_results(topic_1)
      search.close_header
      search.open_header
      search.expect_topic_results(topic_1)
      expect(requests.size).to eq(1)

      logo.click
      ask("reset password")
      search.expect_topic_results(topic_1)
      expect_opening("reset password", tab: "topics", reason: "topic_results")
      search.submit
      expect(page).to have_current_path("/search?q=reset%20password")
      expect(requests.size).to eq(2)

      logo.click
      ask("widget")
      search.expect_tab("topics")
      search.show_more
      expect(page).to have_current_path("/search?q=widget")
      expect(requests.size).to eq(3)
    end

    it "lets the reader request an answer to an operator search only after opening its answer tab" do
      term = "password status:open"
      visit "/"
      search.search(term)

      search.expect_tab("topics")
      expect_opening(term, tab: "topics", reason: "syntax", ask_outcome: "skipped")
      expect(requests).to be_empty
      search.select_tab("ask")
      wait_for_request(term, after: 0)
      search.expect_answer_loading
    end

    context "with a decision model judging intent" do
      fab!(:decision_model)
      before { SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id }

      it "lets the reader follow a model's answer, fall back to keywords or stay on an answer they chose" do
        DiscourseAi::Decisions.with_canned_answers(intent: { "answer" => 0.9, "lookup" => 0.1 }) do
          visit "/"
          ask(query)
          search.expect_tab("ask")
          search.expect_counts(active: "ask", counts: { topics: 1 })
          expect_opening(
            query,
            tab: "ask",
            reason: "intent_answer",
            ask_intent_heuristic: "lookup",
            ask_intent_model: "answer",
            ask_intent_probability: 0.9,
          )
          complete_answer
          search.expect_answer("forgot password")
          search.select_tab("topics")
          search.expect_topic_results(topic_1)

          # A disjoint query avoids searched_again; a new request clears the tab choice.
          term = "account recovery"
          ask(term)
          search.expect_tab("ask")
          expect_opening(term, tab: "ask", reason: "intent_answer")
          empty_answer
          search.expect_tab("topics")
          search.expect_topic_results(topic_1)
        end

        DiscourseAi::Decisions.with_canned_answers(intent: "lookup") do
          term = "login"
          ask(term)
          search.expect_tab("topics")
          expect_opening(term, tab: "topics", reason: "topic_results")
          search.select_tab("ask")
          empty_answer
          search.expect_empty_answer
          search.expect_tab("ask")
        end
      end

      it "keeps rewritten matches while intent is pending and uses keywords before a late verdict" do
        question = "does this site have any guides on that"
        release_intent = Queue.new
        slow_intent = instance_double(DiscourseAi::Discoveries::Intent)
        allow(slow_intent).to receive(:call) do |term, **|
          release_intent.pop
          if term != question
            DiscourseAi::Discoveries::Intent::Judgement.new(intent: "answer", probability: 0.95)
          end
        end
        allow(DiscourseAi::Discoveries::Intent).to receive(:new).and_return(slow_intent)

        visit "/"
        search.search_while_intent_pending(question)
        wait_for_request(question, after: 0)
        publish(
          done: false,
          phase: "rewritten",
          keyword_query: "password",
          semantic_query: "Password guides",
        )
        search.expect_tab("ask")
        search.expect_counts(active: "ask", counts: { topics: 1 })
        release_intent << true
        search.wait_for_intent_reply
        search.select_tab("topics")
        search.expect_topic_results(topic_1)
        expect_opening(question, tab: "ask", reason: "question")

        # These queries share no words; the logged reason must be the keyword fallback.
        search.search_while_intent_pending(query)
        wait_for_request(query, after: 1)
        search.expect_tab("topics")
        search.expect_topic_results(topic_1)
        release_intent << true
        search.wait_for_intent_reply
        expect_opening(query, tab: "topics", reason: "topic_results", ask_intent_model: "answer")
        search.expect_tab("topics")
      ensure
        release_intent << true if release_intent
      end
    end
  end

  context "when searching from somewhere" do
    fab!(:category)
    fab!(:inside) do
      Fabricate(:topic, user: author, category:, title: "Widget setup for this team")
    end
    fab!(:outside) do
      Fabricate(:topic, user: author, title: "Widget setup somewhere else entirely")
    end
    fab!(:inside_post) do
      Fabricate(:post, user: author, topic: inside, raw: "Widget configuration inside the category")
    end
    fab!(:outside_post) do
      Fabricate(
        :post,
        user: author,
        topic: outside,
        raw: "Widget configuration outside the category",
      )
    end
    fab!(:decision_model)
    let(:query) { "widget" }

    before do
      SearchIndexer.enable
      [inside, outside, inside_post].each { |record| SearchIndexer.index(record, force: true) }
    end

    after { SearchIndexer.disable }

    it "lets the reader explore category matches, whole-site answers and a new context" do
      visit category.url
      search.open_header
      search.watch_tab_widths
      ask(query, header: true)

      search.expect_tab("context", label: category.name)
      expect_opening(query, tab: "context", reason: "context_match")
      expect(requests.last.fetch(:scope)).to eq("category:#{category.id}")
      search.expect_counts(active: "context", counts: { topics: 2 })
      search.expect_stable_tab_widths
      search.expect_topic_results(inside, absent: [outside])
      search.select_tab("topics")
      search.expect_topic_results(inside, outside)
      search.expect_counts(active: "topics", counts: { context: 1 })
      expect(requests.size).to eq(1)

      search.select_tab("ask")
      complete_answer(scope_fallback: true, ai_discover_reply: "An answer from elsewhere.")
      search.expect_answer("An answer from elsewhere.")
      search.expect_scope_note(category)
      expect(requests.size).to eq(1)

      # A new request must clear the successful answer and its fallback note.
      ask("widget configuration", header: true)
      expect(requests.last.fetch(:scope)).to eq("category:#{category.id}")
      search.select_tab("ask")
      empty_answer(scope_fallback: true)
      search.expect_empty_answer
      search.expect_scope_note
      search.select_tab("context")
      search.open_topic(inside)
      expect(PageObjects::Pages::Topic.new).to have_topic_title(inside.title)
      search.open_header
      search.expect_query("widget configuration", header: true)
      search.expect_tab("context", label: category.name)
      search.expect_topic_results(inside)
      expect(requests.size).to eq(2)

      # kept from another page, so enter searches here rather than opening it
      search.submit(header: true)
      wait_for_request("widget configuration", after: 2)
      expect(requests.last.fetch(:scope)).to eq("topic:#{inside.id}")
      search.expect_tab_label("context", "This topic")
    end

    it "credits a category result click to the query the reader typed" do
      SiteSetting.log_search_queries = true

      visit category.url
      search.open_header
      ask(query, header: true)
      search.expect_tab("context", label: category.name)
      search.open_topic(inside)
      expect(PageObjects::Pages::Topic.new).to have_topic_title(inside.title)

      try_until_success do
        expect(
          SearchLog.where(user: user).pluck(:term, :search_result_type, :search_result_id),
        ).to contain_exactly([query, SearchLog.search_result_types[:topic], inside_post.id])
      end
    end

    it "keeps a search made in a topic once the reader leaves it, without its topic tab" do
      visit inside.url
      search.open_header
      ask("widget configuration?", header: true)
      search.expect_tab("context", label: "This topic")
      search.select_tab("topics")
      search.open_topic(outside)
      expect(PageObjects::Pages::Topic.new).to have_topic_title(outside.title)

      search.open_header
      search.expect_query("widget configuration?", header: true)
      search.expect_no_tab("context")
      search.expect_tab("topics")
      search.expect_topic_results(inside, outside)
      expect(requests.size).to eq(1)
    end

    it "lets the reader search this topic, ask about missing passages or search the whole site" do
      visit inside.url
      search.open_header
      ask("widget configuration?", header: true)
      search.expect_tab("context", label: "This topic")
      expect_opening("widget configuration?", tab: "context", reason: "topic_match")
      expect(requests.last.fetch(:scope)).to eq("topic:#{inside.id}")

      ask("something nobody wrote about here", header: true)
      search.expect_tab("ask")
      expect_opening("something nobody wrote about here", tab: "ask", reason: "question")

      SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id
      DiscourseAi::Decisions.with_canned_answers(
        intent: "lookup",
        scope: {
          "here" => 0.1,
          "site" => 0.9,
        },
      ) do
        visit inside.url
        search.open_header
        ask("widget configuration", header: true)
        search.expect_tab_label("context", "This topic")
        search.expect_tab("topics")
        expect_opening("widget configuration", tab: "topics", reason: "topic_results")
      end
      expect(requests.last.fetch(:scope)).to be_nil
    end
  end

  context "with a conversation continued from a search" do
    fab!(:bot) { Fabricate(:user, username: "answerbot") }
    fab!(:conversation) do
      Fabricate(:private_message_topic, user:, recipient: bot).tap do |topic|
        topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = true
        topic.custom_fields[
          DiscourseAi::Discoveries::ContinueConversation::TOPIC_REQUEST_ID_FIELD
        ] = "request"
        topic.save_custom_fields
      end
    end
    fab!(:question_post) do
      Fabricate(:post, topic: conversation, user:, raw: "how do I reset my password")
    end
    fab!(:answer_post) do
      Fabricate(
        :post,
        topic: conversation,
        user: bot,
        raw: "See [#{topic_1.title}](#{topic_1.relative_url}) for the steps.",
      )
    end

    it "lets the reader see saved sources, citations and new reply citations instead of the timeline" do
      topic_3 = Fabricate(:topic, user: author, title: "Recovering a lost account")
      conversation.custom_fields[
        DiscourseAi::Discoveries::ContinueConversation::TOPIC_SOURCES_FIELD
      ] = [{ topic_id: topic_2.id, title: topic_2.title, url: topic_2.url }]
      conversation.save_custom_fields
      visit conversation.url
      search.expect_references(topic_1, topic_2)
      search.expect_reference_metadata(topic_1)
      search.expect_no_reference(topic_3)
      channel = "discourse-ai/ai-bot/topic/#{conversation.id}"
      search.wait_for_channel(channel)
      reply =
        Fabricate(
          :post,
          topic: conversation,
          user: bot,
          raw: "Also try [#{topic_3.title}](#{topic_3.url}).",
        )
      MessageBus.publish(
        channel,
        { post_id: reply.id, post_number: reply.post_number, cooked: reply.cooked, done: true },
        user_ids: [user.id],
      )
      search.expect_references(topic_3)

      SiteSetting.enable_ai_combined_search = false
      page.refresh
      search.expect_standard_timeline
    end

    it "lets the reader open citations from the topic map on mobile", mobile: true do
      visit conversation.url
      search.open_mobile_references
      search.expect_references(topic_1, modal: true)
    end
  end

  context "with people and places to find" do
    fab!(:gardening) { Fabricate(:category, name: "Gardening") }
    fab!(:gardener) { Fabricate(:user, username: "plantlover", name: "Green Thumb") }
    fab!(:gardening_topics) do
      [
        "Gardening tips for the spring season",
        "Gardening in small spaces",
        "Gardening with children",
        "Gardening on a budget",
      ].map do |title|
        Fabricate(:topic, user: author, category: gardening, title:).tap do |topic|
          Fabricate(
            :post,
            user: author,
            topic:,
            raw: "Gardening is a lovely way to spend the spring",
          )
        end
      end
    end

    before do
      SearchIndexer.enable
      [*gardening_topics, gardener, gardening].each do |record|
        SearchIndexer.index(record, force: true)
      end
    end

    after { SearchIndexer.disable }

    it "lets the reader choose recent searches, refine a lookup and ask about people or places" do
      SearchLog.log(
        term: "gardening",
        search_type: :header,
        ip_address: "127.0.0.1",
        user_id: user.id,
      )
      visit "/"
      search.select_recent("gardening")
      wait_for_request("gardening", after: 0)
      search.expect_tab("topics")
      search.expect_topic_results(gardening_topics.first)
      search.expect_query("gardening")
      expect(requests.last.fetch(:trigger)).to eq(["recent", ""])
      expect_opening("gardening", tab: "topics", reason: "topic_results")

      ask("spring gardening")
      search.expect_tab("ask")
      expect_opening("spring gardening", tab: "ask", reason: "searched_again")

      previous_count = requests.size
      search.search("green thumb")
      search.expect_tab("topics")
      expect_opening(
        "green thumb",
        tab: "topics",
        reason: "answer_deferred",
        ask_outcome: "skipped",
        answer_deferred_reason: "exact_user_match",
      )
      expect(requests.size).to eq(previous_count)

      search.select_tab("ask")
      wait_for_request("green thumb", after: previous_count)

      ask("gardening?")
      search.expect_tab("ask")
      expect_opening("gardening?", tab: "ask", reason: "question")

      # Syntax precedes searched_again and defers the answer altogether.
      search.search('"small spaces"')
      search.expect_tab("topics")
      search.expect_topic_results(gardening_topics.second)
      expect_opening('"small spaces"', tab: "topics", reason: "syntax", ask_outcome: "skipped")
      expect(requests.size).to eq(4)
    end
  end

  context "when recalling recent searches" do
    before do
      SearchLog.log(
        term: "account recovery",
        search_type: :header,
        ip_address: "127.0.0.1",
        user_id: user.id,
      )
    end

    it "offers history from a page with a search context" do
      visit topic_1.url
      search.open_header

      search.expect_recent("account recovery")
    end

    it "lists a search just run once, ahead of older ones" do
      visit "/about"
      search.open_header
      ask("login help", header: true)

      search.fill_query("", header: true)

      search.expect_recent("login help", "account recovery")
    end

    it "lists a search whose answer was deferred" do
      visit "/about"
      search.open_header
      search.search('"login help"', header: true)
      expect(page).to have_css(".ai-search-tabs")

      search.fill_query("", header: true)

      search.expect_recent('"login help"', "account recovery")
    end
  end
end
