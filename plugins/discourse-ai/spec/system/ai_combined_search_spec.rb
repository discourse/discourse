# frozen_string_literal: true

describe "AI combined search" do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic_1) { Fabricate(:topic, title: "Password resets and account recovery") }
  fab!(:topic_2) { Fabricate(:topic, title: "Login help for new members") }

  let(:query) { "how do I reset my password" }
  let(:request_ids) { [] }
  let(:scopes) { [] }
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
    allow(DiscourseAi::Discoveries).to receive(:enqueue_reply) do |request_id:, scope: nil, **|
      request_ids << request_id
      scopes << scope
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

  def sizes
    page.evaluate_script(<<~JS)
      Object.fromEntries(
        [
          ".ai-search-menu-answer",
          ".ai-search-answer__body",
          ".ai-search-answer__related",
          ".ai-search-answer__follow-up",
          ".ai-search-answer__rewrites",
        ].map((selector) => [
          selector,
          Math.round(document.querySelector(selector).getBoundingClientRect().height),
        ])
      )
    JS
  end

  it "keeps the answer block the same size from placeholder to answer" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    expect(page).to have_css(".ai-search-answer .d-skeleton")

    placeholder = sizes
    page.execute_script(<<~JS)
      window.keywordLabels = [];
      new MutationObserver(() => {
        const text = document.querySelector(".ai-search-answer__rewrites")?.textContent.replace(/\\s+/g, " ").trim();
        if (text) window.keywordLabels.push(text);
      }).observe(document.querySelector(".ai-search-menu-answer"), {
        subtree: true,
        childList: true,
        characterData: true,
      });
    JS

    publish(
      done: false,
      phase: "rewritten",
      keyword_query: "reset password",
      semantic_query: "How can I reset a forgotten password?",
    )
    publish(done: false, phase: "sources", ai_discover_title: "Resetting your password", sources:)

    expect(page).to have_css(".ai-search-answer__related-link", count: 2)
    expect(page).to have_css(".ai-search-answer__rewrites", text: "Keywords: reset password")
    expect(sizes).to eq(placeholder)
    expect(page.evaluate_script("window.keywordLabels")).to all(eq("Keywords: reset password"))

    publish(
      done: true,
      phase: "complete",
      answerable: true,
      ai_discover_title: "Resetting your password",
      ai_discover_reply: "Use the **forgot password** link on the login screen. " * 12,
      ai_discover_follow_up: "What if I no longer have access to my email?",
      sources:,
    )

    expect(page).to have_no_css(".ai-search-answer .d-skeleton")
    expect(page).to have_css(".ai-search-answer__body .cooked", text: "forgot password")
    expect(sizes).to eq(placeholder)

    body = find(".ai-search-answer__body")
    expect(body).to match_style(overflow: "hidden")
    expect(body).to have_css(".ai-search-answer__expand", text: "Show more")

    # opening it is the one change the reader asks for
    find(".ai-search-answer__expand").click
    expect(body).to have_css(".ai-search-answer__expand", text: "Show less")
    expect(sizes[".ai-search-answer__body"]).to be > placeholder[".ai-search-answer__body"]
  end

  context "with keyword results" do
    let(:query) { "password" }

    before do
      Fabricate(:post, topic: topic_1, raw: "Reset your password from the login screen")
      SearchIndexer.enable
      SearchIndexer.index(topic_1, force: true)
    end

    after { SearchIndexer.disable }

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

      expect(page).to have_css(".search-menu .ai-search-best-match", count: 1)
      expect(find(".search-menu .ai-search-best-match").text).to be_blank
      expect(page.evaluate_script(row_height)).to eq(before)
      overhang = page.evaluate_script(<<~JS)
        (() => {
          const sticker = document.querySelector(".search-menu .ai-search-best-match").getBoundingClientRect();
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
        sources:,
      )
      expect(page).to have_css(".search-menu .ai-search-best-match")

      offsets = page.evaluate_script(<<~JS)
          (() => {
            const sticker = () => document.querySelector(".search-menu .ai-search-best-match").getBoundingClientRect();
            const row = () => document.querySelector(".search-menu .search-result-topic .item");
            const offset = () => Math.round(sticker().top - row().getBoundingClientRect().top);
            const list = document.querySelector(".search-menu .panel-body-contents");

            row().scrollIntoView({ block: "end" });
            const shown = sticker();
            const centre = document.elementFromPoint(shown.left + shown.width / 2, shown.top + shown.height / 2);
            const hangs = shown.left < row().getBoundingClientRect().left && Boolean(centre?.closest(".ai-search-best-match"));
            const before = offset();
            const scrolledFrom = list.scrollTop;

            list.scrollTop = 0;
            return { hangs, scrolled: list.scrollTop !== scrolledFrom, before, after: offset() };
          })()
        JS
      expect(offsets["hangs"]).to eq(true)
      expect(offsets["scrolled"]).to eq(true)
      expect(offsets["after"]).to eq(offsets["before"])

      edges = page.evaluate_script(<<~JS)
          ["search-input", "ai-search-answer__body", "ai-search-answer__follow-up"].map((name) => {
            const box = document.querySelector(`.search-menu .${name}`).getBoundingClientRect();
            return [Math.round(box.left), Math.round(box.right)];
          })
        JS
      expect(edges.uniq.size).to eq(1), "the answer lines up with the search field: #{edges}"
    ensure
      page.current_window.resize_to(1400, 1400)
    end
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
      ai_discover_reply: "An answer.",
      sources:,
    )
    expect(page).to have_no_css(".ai-search-answer .d-skeleton")

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

    it "scopes the answer and results to the category, and the chip can be taken off and put back" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search

      expect(page).to have_css(".ai-search-scope-chip", text: "in #{category.name}")

      ask(query, input: "#icon-search-input")

      expect(scopes.last).to eq("category:#{category.id}")
      expect(page).to have_css(".search-menu .search-result-topic", text: inside.title)
      expect(page).to have_no_css(".search-menu .search-result-topic", text: outside.title)

      find(".ai-search-scope-chip").click

      expect(page).to have_no_css(".ai-search-scope-chip")
      try_until_success { expect(request_ids.size).to eq(2) }
      expect(scopes.last).to be_nil
      expect(page).to have_css(".search-menu .search-result-topic", text: outside.title)

      # a long keyword query gives way to the link rather than pushing it out
      publish(
        done: false,
        phase: "rewritten",
        keyword_query: "widget #{"configuration " * 20}",
        semantic_query: "widget",
      )
      expect(page).to have_css(".ai-search-answer__rewrite", text: "configuration configuration")
      layout = page.evaluate_script(<<~JS)
          (() => {
            const line = document.querySelector(".ai-search-answer__rewrites").getBoundingClientRect();
            const keywords = document.querySelector(".ai-search-answer__rewrite");
            const link = document.querySelector(".ai-search-answer__restore-scope").getBoundingClientRect();
            return {
              linkInside: link.right <= line.right + 1,
              keywordsTruncated: keywords.scrollWidth > keywords.clientWidth,
            };
          })()
        JS
      expect(layout).to eq("linkInside" => true, "keywordsTruncated" => true)

      find(".ai-search-answer__restore-scope", text: "Search in #{category.name} only").click

      expect(page).to have_css(".ai-search-scope-chip", text: "in #{category.name}")
      try_until_success { expect(request_ids.size).to eq(3) }
      expect(scopes.last).to eq("category:#{category.id}")
      expect(page).to have_no_css(".search-menu .search-result-topic", text: outside.title)
    end

    it "puts a removed chip back when the search is cleared, without asking again" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")

      find(".ai-search-scope-chip").click
      try_until_success { expect(request_ids.size).to eq(2) }

      find(".search-menu .clear-search").click

      expect(page).to have_css(".ai-search-scope-chip", text: "in #{category.name}")
      expect(find("#icon-search-input").value).to be_blank
      expect(page).to have_no_css(".ai-search-menu-answer")
      expect(request_ids.size).to eq(2)
    end

    it "says when the answer had to come from the whole site" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")

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
    end

    it "does not mention the whole site when no answer was found there either" do
      visit category.url
      wait_for_discoveries_channel
      open_header_search
      ask(query, input: "#icon-search-input")

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

    it "scopes to the topic being read" do
      visit inside.url
      wait_for_discoveries_channel
      open_header_search

      expect(page).to have_css(".ai-search-scope-chip", text: "in this topic")

      ask(query, input: "#icon-search-input")

      expect(scopes.last).to eq("topic:#{inside.id}")
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
end
