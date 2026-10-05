# frozen_string_literal: true

describe "AI combined search" do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic_1) { Fabricate(:topic, title: "Password resets and account recovery") }
  fab!(:topic_2) { Fabricate(:topic, title: "Login help for new members") }

  let(:query) { "how do I reset my password" }
  let(:request_ids) { [] }
  let(:scopes) { [] }
  let(:triggers) { [] }
  let(:sources) do
    [topic_1, topic_2].map do |topic|
      { title: topic.title, url: topic.url, excerpt: "An excerpt about #{topic.title}" }
    end
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    assign_agent_to(:ai_ask_ai_agent, [Group::AUTO_GROUPS[:admins]])

    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    SiteSetting.ai_ask_ai_combined_search_prototype = true

    # the answer is streamed from the spec instead, one phase at a time
    allow(DiscourseAi::Discoveries).to receive(
      :enqueue_reply,
    ) do |request_id:, scope: nil, trigger: "", trigger_reason: "", **|
      request_ids << request_id
      scopes << scope
      triggers << [trigger, trigger_reason]
    end

    sign_in(user)
  end

  def publish(payload)
    MessageBus.publish(
      "/discourse-ai/discoveries",
      { query:, request_id: request_ids.last }.merge(payload),
      user_ids: [user.id],
    )
  end

  def wait_for_discoveries_channel
    # updates published before the client knows its position on the channel
    # are skipped, which a real answer never outpaces
    try_until_success(timeout: 10) { expect(page.evaluate_script(<<~JS)).to eq(true) }
        MessageBus.callbacks.some(
          (callback) => callback.channel === "/discourse-ai/discoveries" && callback.last_id !== -1
        )
      JS
  end

  def ask(term, input: "#welcome-banner-search-input")
    find(input).fill_in(with: term)
    find(input).send_keys(:enter)
    try_until_success { expect(request_ids).to be_present }
  end

  def tab(kind)
    ".ai-search-tabs .ai-discoveries-search-options__option.--#{kind}"
  end

  def expect_tab(kind)
    expect(page).to have_css("#{tab(kind)}.is-active")
  end

  def select_tab(kind)
    find(tab(kind)).click
    expect_tab(kind)
  end

  it "streams the answer in full, adding its related topics once it is done" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    # a question opens on the answer
    expect_tab("ask")
    expect(page).to have_css(".ai-search-answer .d-skeleton")
    expect(page).to have_no_css("#{tab("ask")} .ai-search-best-match")
    width_before =
      page.evaluate_script(
        "Math.round(document.querySelector('#{tab("ask")}').getBoundingClientRect().width)",
      )

    publish(
      done: false,
      phase: "rewritten",
      keyword_query: "reset password",
      semantic_query: "How can I reset a forgotten password?",
    )
    publish(done: false, phase: "sources", ai_discover_title: "Resetting your password", sources:)
    publish(done: false, phase: "answering", ai_discover_reply: "Use the **forgot")

    expect(page).to have_css(".ai-search-answer__body .cooked", text: "Use the")
    # the results' star marks that there is an answer, without resizing the pill
    expect(page).to have_css("#{tab("ask")} .ai-search-best-match[title='AI answer found']")
    expect(
      page.evaluate_script(
        "Math.round(document.querySelector('#{tab("ask")}').getBoundingClientRect().width)",
      ),
    ).to eq(width_before)
    # added once the answer is complete, so they do not slide down as it streams
    expect(page).to have_no_css(".ai-search-answer__more")

    publish(
      done: true,
      phase: "complete",
      answerable: true,
      ai_discover_title: "Resetting your password",
      ai_discover_reply: "Use the **forgot password** link on the login screen. " * 12,
      ai_discover_follow_up: "What if I no longer have access to my email?",
      sources:,
    )

    expect(page).to have_css(".ai-search-answer__body .cooked", text: "forgot password")
    within(".ai-search-answer__more") do
      expect(page).to have_css(".ai-search-answer__related-link", count: 2)
      expect(page).to have_css(
        ".ai-search-answer__follow-up-input[placeholder='What if I no longer have access to my email?']",
      )
    end
    expect(page).to have_no_css(".ai-search-answer__expand")
    expect(page).to have_no_text("Keywords")
  end

  it "gives a lone related topic the full width" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    publish(
      done: true,
      phase: "complete",
      answerable: true,
      ai_discover_reply: "Use the forgot password link.",
      sources: sources.first(1),
    )
    expect(page).to have_css(".ai-search-answer__related-item")

    widths = page.evaluate_script(<<~JS)
        ["ai-search-answer__related", "ai-search-answer__related-item"].map((name) =>
          Math.round(document.querySelector(`.${name}`).getBoundingClientRect().width)
        )
      JS
    expect(widths.uniq.size).to eq(1)
  end

  it "opens on the answer when nothing matches the keywords, and says so on the topics tab" do
    visit "/"
    wait_for_discoveries_channel
    ask("unheard of things")

    expect_tab("ask")
    expect(page).to have_css("#{tab("topics")}.--empty .ai-search-tabs__count", text: "0")

    select_tab("topics")
    expect(page).to have_css(".search-menu .no-results", text: "No keyword matches found.")
    expect(page).to have_no_text("No results found.")
  end

  it "marks the answer tab when no answer was found" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    publish(done: true, phase: "complete", answerable: false, ai_discover_reply: "", sources: [])

    expect(page).to have_css("#{tab("ask")} .ai-search-tabs__empty .d-icon-ban")
    expect(page).to have_no_css("#{tab("ask")} .ai-search-best-match")
  end

  it "opens on the answer for a query outside the site's language" do
    visit "/"
    wait_for_discoveries_channel
    ask("сброс")

    expect_tab("ask")
    expect(triggers.last).to eq(["enter", ""])
  end

  it "waits for enter rather than searching as the reader types" do
    visit "/"
    wait_for_discoveries_channel

    find("#welcome-banner-search-input").fill_in(with: query)
    expect(page).to have_no_css(".ai-search-tabs")
    expect(request_ids).to be_empty

    find("#welcome-banner-search-input").send_keys(:enter)
    try_until_success { expect(request_ids.size).to eq(1) }
    expect(page).to have_css(".ai-search-tabs")
  end

  context "with keyword results" do
    let(:query) { "password" }

    before do
      Fabricate(:post, topic: topic_1, raw: "Reset your password from the login screen")
      SearchIndexer.enable
      SearchIndexer.index(topic_1, force: true)
    end

    after { SearchIndexer.disable }

    it "opens a lookup on its topics, with every tab fetched at once" do
      visit "/"
      wait_for_discoveries_channel
      ask(query)

      expect_tab("topics")
      expect(page).to have_css("#{tab("topics")} .ai-search-tabs__count", text: "1")
      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)

      # the answer was asked for with the rest, so switching asks nothing more
      select_tab("ask")
      expect(page).to have_css(".ai-search-answer")
      expect(page).to have_no_css(".search-menu .search-result-topic")
      publish(
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_reply: "An answer.",
        sources:,
      )
      expect(page).to have_css(".ai-search-answer__body .cooked", text: "An answer.")

      select_tab("topics")
      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)
      expect(request_ids.size).to eq(1)
    end

    it "leaves related results to the combined search, so the list holds still" do
      SiteSetting.ai_embeddings_semantic_quick_search_enabled = true

      visit "/"
      wait_for_discoveries_channel
      ask(query)
      publish(
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_reply: "Use the forgot password link.",
        sources:,
      )

      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)
      expect(page).to have_no_css(".ai-quick-search-notice")
      expect(page).to have_no_css(".search-menu .ai-search-result")
    end

    it "puts a sticker on the best matches without moving them" do
      visit "/"
      wait_for_discoveries_channel
      ask(query)

      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)
      row_height = <<~JS
        Math.round(document.querySelector(".search-menu .search-result-topic .item").getBoundingClientRect().height)
      JS
      before = page.evaluate_script(row_height)

      publish(
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_reply: "Use the forgot password link.",
        sources:,
      )

      expect(page).to have_css(".search-menu .search-result-topic .ai-search-best-match", count: 1)
      expect(find(".search-menu .search-result-topic .ai-search-best-match").text).to be_blank
      expect(page.evaluate_script(row_height)).to eq(before)
      overhang = page.evaluate_script(<<~JS)
        (() => {
          const sticker = document.querySelector(".search-menu .search-result-topic .ai-search-best-match").getBoundingClientRect();
          const row = document.querySelector(".search-menu .search-result-topic .item").getBoundingClientRect();
          const centre = document.elementFromPoint(sticker.left + sticker.width / 2, sticker.top + sticker.height / 2);
          return {
            hangs: sticker.left < row.left,
            visible: Boolean(centre?.closest(".ai-search-best-match")),
          };
        })()
      JS
      expect(overhang).to eq("hangs" => true, "visible" => true)
    end

    it "scrolls the sticker with its result in the header search" do
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      # enough results to overflow the menu
      extra_topics =
        8.times.map do |index|
          topic = Fabricate(:topic, title: "Password question number #{index + 1} here")
          Fabricate(:post, topic:, raw: "Another password question")
          SearchIndexer.index(topic, force: true)
          topic
        end
      cited =
        [topic_1, *extra_topics].map { |topic| { title: topic.title, url: topic.url, excerpt: "" } }
      page.current_window.resize_to(1400, 450)

      visit "/"
      wait_for_discoveries_channel
      find("#search-button").click
      ask(query, input: "#icon-search-input")
      publish(
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_reply: "Use the forgot password link.",
        sources: cited,
      )
      expect(page).to have_css(".search-menu .search-result-topic .ai-search-best-match")

      offsets = page.evaluate_script(<<~JS)
          (() => {
            const sticker = () => document.querySelector(".search-menu .search-result-topic .ai-search-best-match").getBoundingClientRect();
            const row = () => document.querySelector(".search-menu .search-result-topic .ai-search-best-match").closest(".item");
            const offset = () => Math.round(sticker().top - row().getBoundingClientRect().top);
            const list = document.querySelector(".search-menu .panel-body-contents");

            list.scrollTop = 0;
            row().scrollIntoView({ block: "nearest" });
            const shown = sticker();
            const centre = document.elementFromPoint(shown.left + shown.width / 2, shown.top + shown.height / 2);
            const hangs = shown.left < row().getBoundingClientRect().left && Boolean(centre?.closest(".ai-search-best-match"));
            const before = offset();
            const scrolledFrom = list.scrollTop;

            list.scrollTop = list.scrollHeight;
            return { hangs, scrolled: list.scrollTop !== scrolledFrom, before, after: offset() };
          })()
        JS
      expect(offsets["hangs"]).to eq(true)
      expect(offsets["scrolled"]).to eq(true)
      expect(offsets["after"]).to eq(offsets["before"])
    ensure
      page.current_window.resize_to(1400, 1400)
    end
  end

  it "offers to ask the community when no answer is found" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    publish(done: true, phase: "complete", answerable: false, ai_discover_reply: "", sources: [])

    expect(page).to have_css(".ai-search-answer__empty", text: "AI couldn’t find a clear answer.")
    find(".ai-search-answer__ask-community", text: "Ask the community.").click

    expect(page).to have_css("#reply-control.open")
    expect(find("#reply-title").value).to eq(query)
  end

  it "centres the message when no answer is found" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    publish(done: true, phase: "complete", answerable: false, ai_discover_reply: "", sources: [])

    expect(page).to have_css(".ai-search-answer__empty")
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

  it "keeps the results scrollable" do
    page.current_window.resize_to(1400, 450)

    visit "/"
    wait_for_discoveries_channel
    ask(query)
    publish(
      done: true,
      phase: "complete",
      answerable: true,
      ai_discover_reply: "A long answer that runs on. " * 40,
      sources:,
    )
    # long enough to run past the window
    expect(page).to have_css(".ai-search-answer__more")

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
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  context "when searching from somewhere" do
    fab!(:category)
    fab!(:inside) { Fabricate(:topic, category:, title: "Widget setup for this team") }
    fab!(:outside) { Fabricate(:topic, title: "Widget setup somewhere else entirely") }
    let(:query) { "widget" }

    before do
      Fabricate(:post, topic: inside, raw: "Widget configuration inside the category")
      Fabricate(:post, topic: outside, raw: "Widget configuration outside the category")
      SearchIndexer.enable
      [inside, outside].each { |topic| SearchIndexer.index(topic, force: true) }
    end

    after { SearchIndexer.disable }

    def open_header_search
      find("#search-button").click
      expect(page).to have_css("#icon-search-input")
    end

    it "offers the category as a tab, opening on it when it has matches" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      page.execute_script(<<~JS)
        window.pillWidths = {};
        new MutationObserver(() => {
          document.querySelectorAll(".ai-search-tabs .ai-discoveries-search-options__option").forEach((pill) => {
            const kind = [...pill.classList].find((name) => name.startsWith("--") && name !== "--empty");
            (window.pillWidths[kind] ??= new Set()).add(Math.round(pill.getBoundingClientRect().width));
          });
        }).observe(document.body, { subtree: true, childList: true, characterData: true });
      JS
      ask(query, input: "#icon-search-input")

      expect(page).to have_css(tab("context"), text: category.name)
      expect_tab("context")
      expect(scopes.last).to eq("category:#{category.id}")
      expect(page).to have_css("#{tab("context")} .ai-search-tabs__count", text: "1")
      expect(page).to have_css("#{tab("topics")} .ai-search-tabs__count", text: "2")
      # the counts hang off the pills rather than widening them
      widths = page.evaluate_script(<<~JS)
        Object.fromEntries(Object.entries(window.pillWidths).map(([kind, set]) => [kind, set.size]))
      JS
      expect(widths.values).to all(eq(1))
      expect(page).to have_css(".search-menu .search-result-topic", text: inside.title)
      expect(page).to have_no_css(".search-menu .search-result-topic", text: outside.title)

      select_tab("topics")
      expect(page).to have_css(".search-menu .search-result-topic", text: outside.title)
      expect(request_ids.size).to eq(1)
    end

    it "says when the answer had to come from the whole site" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")
      select_tab("ask")

      publish(
        done: true,
        phase: "complete",
        answerable: true,
        scope_fallback: true,
        ai_discover_reply: "An answer from elsewhere.",
        sources:,
      )

      expect(page).to have_css(
        ".ai-search-answer__scope-note",
        text: "Nothing found in #{category.name}",
      )
      expect(request_ids.size).to eq(1)
    end

    it "does not mention the whole site when no answer was found there either" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")
      select_tab("ask")

      publish(
        done: true,
        phase: "complete",
        answerable: false,
        scope_fallback: true,
        ai_discover_reply: "",
        sources: [],
      )

      expect(page).to have_css(".ai-search-answer__empty")
      expect(page).to have_no_css(".ai-search-answer__scope-note")
    end

    it "opens a topic search on the topic when its posts match, and on the answer when not" do
      inside.posts.each { |post| SearchIndexer.index(post, force: true) }

      visit inside.url
      wait_for_discoveries_channel
      open_header_search
      ask("widget configuration?", input: "#icon-search-input")

      expect(page).to have_css(tab("context"), text: "This topic")
      expect_tab("context")
      expect(scopes.last).to eq("topic:#{inside.id}")

      find("#icon-search-input").fill_in(with: "something nobody wrote about here")
      find("#icon-search-input").send_keys(:enter)

      try_until_success { expect(request_ids.size).to eq(2) }
      expect_tab("ask")
    end

    it "starts afresh in a new context rather than searching again" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")
      expect(page).to have_css(".search-menu .search-result-topic", text: inside.title)

      find(".search-menu .search-result-topic a", text: inside.title).click
      expect(page).to have_current_path(%r{/t/})

      open_header_search

      expect(find("#icon-search-input").value).to be_blank
      expect(page).to have_no_css(".ai-search-tabs")
      expect(request_ids.size).to eq(1)
    end
  end

  context "with the full page" do
    fab!(:bot) { Fabricate(:user, username: "answerbot") }

    it "follows the query through history" do
      visit "/discourse-ai/discoveries/search?q=first"
      expect(find(".ai-search__query-input").value).to eq("first")

      find(".ai-search__query-input").fill_in(with: "second")
      find(".ai-search__query-input").send_keys(:enter)
      expect(page).to have_current_path(/q=second/)

      page.go_back

      expect(page).to have_current_path(/q=first/)
      expect(find(".ai-search__query-input").value).to eq("first")
    end

    it "keeps a finished answer when its closing stream message is replayed" do
      conversation = Fabricate(:private_message_topic, user:, recipient: bot)
      Fabricate(:post, topic: conversation, user:, raw: "How do widgets work?")
      Fabricate(:post, topic: conversation, user: bot, raw: "Widgets work like this.")
      Fabricate(:post, topic: conversation, user:, raw: "And gadgets?")
      reply = Fabricate(:post, topic: conversation, user: bot, raw: "Gadgets are similar.")

      visit "/discourse-ai/discoveries/search?topic=#{conversation.id}"
      expect(page).to have_css(".ai-search__turn.--answer .cooked", text: "Gadgets are similar")

      MessageBus.publish(
        "discourse-ai/ai-bot/topic/#{conversation.id}",
        { post_id: reply.id, post_number: reply.post_number, cooked: reply.cooked, done: true },
        user_ids: [user.id],
      )

      expect(page).to have_css(".ai-search__turn.--answer .cooked", text: "Gadgets are similar")
      expect(page).to have_css(".ai-search__turn.--question", text: "And gadgets?")
    end
  end

  context "with people and places to find" do
    fab!(:gardening) { Fabricate(:category, name: "Gardening") }
    fab!(:gardener) { Fabricate(:user, username: "plantlover", name: "Green Thumb") }

    before do
      SearchIndexer.enable
      [
        "Gardening tips for the spring season",
        "Gardening in small spaces",
        "Gardening with children",
        "Gardening on a budget",
      ].each do |title|
        topic = Fabricate(:topic, category: gardening, title:)
        Fabricate(:post, topic:, raw: "Gardening is a lovely way to spend the spring")
        SearchIndexer.index(topic, force: true)
      end
      SearchIndexer.index(gardener, force: true)
      SearchIndexer.index(gardening, force: true)
    end

    after { SearchIndexer.disable }

    it "opens a lookup on its topics" do
      visit "/"
      wait_for_discoveries_channel
      ask("gardening")

      expect_tab("topics")
      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")
    end

    it "opens on the answer when only a person matches" do
      visit "/"
      wait_for_discoveries_channel
      ask("green thumb")

      expect_tab("ask")
    end

    it "opens a question on the answer even when places match" do
      visit "/"
      wait_for_discoveries_channel
      ask("gardening?")

      expect_tab("ask")
    end

    it "opens a query in search syntax on its topics" do
      visit "/"
      wait_for_discoveries_channel
      ask('"small spaces"')

      expect_tab("topics")
      expect(page).to have_css(
        ".search-menu .search-result-topic",
        text: "Gardening in small spaces",
      )
    end

    it "opens on the answer when the reader searches again on the same page" do
      visit "/"
      wait_for_discoveries_channel
      ask("gardening")
      expect_tab("topics")

      find("#welcome-banner-search-input").fill_in(with: "spring gardening")
      find("#welcome-banner-search-input").send_keys(:enter)

      try_until_success { expect(request_ids.size).to eq(2) }
      expect_tab("ask")
    end

    it "runs the combined search for a recent search picked from the menu" do
      SearchLog.log(
        term: "gardening",
        search_type: :header,
        ip_address: "127.0.0.1",
        user_id: user.id,
      )

      visit "/"
      wait_for_discoveries_channel
      find("#welcome-banner-search-input").click
      find(".search-menu-recent .search-menu-assistant-item", text: "gardening").click

      expect_tab("topics")
      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")
      expect(find("#welcome-banner-search-input").value).to eq("gardening")
      expect(triggers.last).to eq(["recent", ""])
    end
  end
end
