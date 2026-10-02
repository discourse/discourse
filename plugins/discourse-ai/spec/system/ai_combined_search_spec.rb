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

  def sizes
    page.evaluate_script(<<~JS)
      Object.fromEntries(
        [".ai-search-menu-answer", ".ai-search-answer__body"].map((selector) => [
          selector,
          Math.round(document.querySelector(selector).getBoundingClientRect().height),
        ])
      )
    JS
  end

  it "keeps the answer the same size from placeholder to answer, and opens on request" do
    visit "/"
    wait_for_discoveries_channel
    ask(query)

    expect(page).to have_css(".ai-search-answer .d-skeleton")
    placeholder = sizes
    box = <<~JS
      (selector) => {
        const rect = document.querySelector(selector).getBoundingClientRect();
        return [rect.left, rect.top, rect.width, rect.height].map(Math.round);
      }
    JS
    button_placeholder = page.evaluate_script("(#{box})('.ai-search-answer__expand-skeleton')")

    publish(
      done: false,
      phase: "rewritten",
      keyword_query: "reset password",
      semantic_query: "How can I reset a forgotten password?",
    )
    publish(done: false, phase: "sources", ai_discover_title: "Resetting your password", sources:)
    publish(done: false, phase: "answering", ai_discover_reply: "Use the **forgot")

    # offered from the first words, so it does not pop in partway through, and
    # it takes the place its placeholder held
    expect(page).to have_css(".ai-search-answer__body .cooked", text: "Use the")
    expect(page).to have_css(".ai-search-answer__expand", text: "Show more")
    button = page.evaluate_script("(#{box})('.ai-search-answer__expand')")
    button.zip(button_placeholder).each { |actual, held| expect(actual).to be_within(1).of(held) }
    expect(sizes).to eq(placeholder)

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
    expect(sizes).to eq(placeholder)

    # nothing matched the keywords, and the menu says which results it means
    expect(page).to have_css(".search-menu .no-results", text: "No keyword matches found.")
    expect(page).to have_no_text("No results found.")

    # related topics, the follow-up and the keywords are not shown until asked
    expect(page).to have_no_css(".ai-search-answer__related")
    expect(page).to have_no_css(".ai-search-answer__follow-up")
    expect(page).to have_no_text("Keywords")

    body = find(".ai-search-answer__body")
    expect(body).to match_style(overflow: "hidden")

    find(".ai-search-answer__expand", text: "Show more").click

    expect(page).to have_css(".ai-search-answer__expand", text: "Show less")
    expect(page).to have_css(".ai-search-answer__related-link", count: 2)
    expect(page).to have_css(
      ".ai-search-answer__follow-up-input[placeholder='What if I no longer have access to my email?']",
    )
    expect(sizes[".ai-search-answer__body"]).to be > placeholder[".ai-search-answer__body"]
  end

  it "offers more for a short answer that fits" do
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

    find(".ai-search-answer__expand", text: "Show more").click
    expect(page).to have_css(".ai-search-answer__related-link", count: 2)
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
    find(".ai-search-answer__expand", text: "Show more").click

    widths = page.evaluate_script(<<~JS)
        ["ai-search-answer__related", "ai-search-answer__related-item"].map((name) =>
          Math.round(document.querySelector(`.${name}`).getBoundingClientRect().width)
        )
      JS
    expect(widths.uniq.size).to eq(1)
  end

  it "answers a query written outside the site's language" do
    visit "/"
    wait_for_discoveries_channel

    find("#welcome-banner-search-input").fill_in(with: "сброс пароля")

    try_until_success { expect(request_ids.size).to eq(1) }
    expect(triggers.last).to eq(%w[pause language])
  end

  it "searches a pasted query once it settles, with no keys pressed" do
    visit "/"
    wait_for_discoveries_channel
    find("#welcome-banner-search-input").click

    page.execute_script(<<~JS, query)
      const input = document.querySelector("#welcome-banner-search-input");
      input.value = arguments[0];
      input.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertFromPaste" }));
    JS

    try_until_success { expect(request_ids.size).to eq(1) }
    expect(triggers.last).to eq(%w[pause question])
  end

  it "searches once typing pauses, clearing the answer as soon as the term changes" do
    visit "/"
    wait_for_discoveries_channel

    find("#welcome-banner-search-input").fill_in(with: query)
    try_until_success { expect(request_ids.size).to eq(1) }
    expect(page).to have_css(".ai-search-answer .d-skeleton")

    publish(
      done: true,
      phase: "complete",
      answerable: true,
      ai_discover_reply: "First answer.",
      sources:,
    )
    expect(page).to have_css(".ai-search-answer__body .cooked", text: "First answer")

    find("#welcome-banner-search-input").send_keys(" quickly")
    expect(page).to have_no_css(".ai-search-answer__body .cooked", text: "First answer")

    try_until_success { expect(request_ids.size).to eq(2) }
    expect(page).to have_css(".ai-search-answer .d-skeleton")
  end

  context "with keyword results" do
    let(:query) { "password" }

    before do
      Fabricate(:post, topic: topic_1, raw: "Reset your password from the login screen")
      SearchIndexer.enable
      SearchIndexer.index(topic_1, force: true)
    end

    after { SearchIndexer.disable }

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

    it "gives an opened answer the menu to itself" do
      visit "/"
      wait_for_discoveries_channel
      ask(query)
      publish(
        done: true,
        phase: "complete",
        answerable: true,
        ai_discover_reply: "Use the forgot password link.",
        ai_discover_follow_up: "What about two-factor?",
        sources:,
      )
      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)

      find(".ai-search-answer__expand").click

      within(".ai-search-answer__more") do
        expect(page).to have_css(".ai-search-answer__related-link", count: 2)
        expect(page).to have_css(".ai-search-answer__follow-up")
      end
      expect(page).to have_no_css(".search-menu .search-result-topic")
      expect(page).to have_no_css(".ai-search-entities")

      find(".ai-search-answer__expand", text: "Show less").click

      expect(page).to have_css(".search-menu .search-result-topic", text: topic_1.title)
      expect(page).to have_no_css(".ai-search-answer__more")
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
      expect(page).to have_css(".search-menu .ai-search-best-match")

      offsets = page.evaluate_script(<<~JS)
          (() => {
            const sticker = () => document.querySelector(".search-menu .ai-search-best-match").getBoundingClientRect();
            const row = () => document.querySelector(".search-menu .ai-search-best-match").closest(".item");
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
      ai_discover_reply: "An answer.",
      sources:,
    )
    expect(page).to have_no_css(".ai-search-answer .d-skeleton")
    # opened, so the menu runs past the window
    find(".ai-search-answer__expand").click

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

      expect(page).to have_css(".ai-search-entities__restore .d-icon-filter")
      find(".ai-search-entities__restore", text: "Search in #{category.name} only").click

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

      # the search follows the answer out of the category, without asking again
      expect(page).to have_no_css(".ai-search-scope-chip")
      expect(page).to have_css(".ai-search-entities__restore", text: category.name)
      expect(page).to have_css(".search-menu .search-result-topic", text: outside.title)
      expect(request_ids.size).to eq(1)
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

    it "only searches a topic when its posts match, and answers when none do" do
      inside.posts.each { |post| SearchIndexer.index(post, force: true) }

      visit inside.url
      wait_for_discoveries_channel
      open_header_search

      find("#icon-search-input").fill_in(with: "widget configuration?")

      expect(page).to have_css(
        ".search-menu .search-result-post, .search-menu .search-result-topic",
      )
      expect(page).to have_no_css(".ai-search-answer")
      expect(request_ids).to be_empty

      find("#icon-search-input").fill_in(with: "something nobody wrote about here")

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(triggers.last).to eq(%w[pause no_topic_match])
      expect(scopes.last).to eq("topic:#{inside.id}")
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
      expect(page).to have_no_css(".ai-search-answer")
      expect(request_ids.size).to eq(1)
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

  context "when a pause finds a lookup rather than a question" do
    fab!(:gardening) { Fabricate(:category, name: "Gardening") }
    fab!(:gardener) { Fabricate(:user, username: "plantlover", name: "Green Thumb") }

    before do
      SearchIndexer.enable
      # more keyword matches than would warrant an answer on their own
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

    it "only searches when people or places match, and answers on enter" do
      visit "/"
      wait_for_discoveries_channel

      page.execute_script(<<~JS)
        window.appeared = [];
        new MutationObserver(() => {
          const seen = {
            places: document.querySelector(".ai-search-entities"),
            topics: document.querySelector(".search-menu .search-result-topic"),
            coreList: document.querySelector(".search-menu .search-result-user, .search-menu .search-result-category"),
          };
          for (const [name, element] of Object.entries(seen)) {
            const last = window.appeared.filter((entry) => entry.startsWith(name + ":")).pop();
            const state = element ? "shown" : "gone";
            if ((last ?? `${name}:gone`) !== `${name}:${state}`) {
              window.appeared.push(`${name}:${state}`);
            }
          }
        }).observe(document.body, { subtree: true, childList: true });
      JS

      find("#welcome-banner-search-input").fill_in(with: "gardening")

      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")
      # the matches are in place before the pause, so nothing pops in when it
      # runs, and core's own list of names never shows
      appeared = page.evaluate_script("window.appeared")
      expect(appeared.index("places:shown")).to be < appeared.index("topics:shown")
      expect(appeared).not_to include("places:gone")
      expect(appeared).not_to include("coreList:shown")
      expect(page).to have_css(".ai-search-entities", text: "Gardening")
      expect(page).to have_no_css(".ai-search-answer")
      expect(request_ids).to be_empty

      find("#welcome-banner-search-input").send_keys(:enter)

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(page).to have_css(".ai-search-answer .d-skeleton")
    end

    it "still asks AI when a person matches but hardly any topics do" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "green thumb")

      expect(page).to have_css(".ai-search-entities", text: "plantlover")
      try_until_success { expect(request_ids.size).to eq(1) }
      expect(page).to have_css(".ai-search-answer .d-skeleton")
    end

    it "asks AI for a single word that matches nothing but topics" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "spring")

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(page).to have_css(".ai-search-answer .d-skeleton")
    end

    it "shows matching groups and tags the way search does elsewhere" do
      SiteSetting.tagging_enabled = true
      Fabricate(:group, name: "gardeners", full_name: "Garden club")
      tag = Fabricate(:tag, name: "garden-tips")
      Fabricate(:topic, tags: [tag])

      visit "/"
      wait_for_discoveries_channel
      find("#welcome-banner-search-input").fill_in(with: "garden")

      expect(page).to have_css(".ai-search-entities__item.--group", text: "Garden club")
      expect(page).to have_css(".ai-search-entities__item.--group .d-icon-users")
      expect(page).to have_css(".ai-search-entities__item.--tag .d-icon-tag")
      expect(page).to have_css(
        ".ai-search-entities__item.--tag[href*='/tag/garden-tips']",
        text: "garden-tips",
      )
    end

    it "answers a question even when places match" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "gardening?")

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(page).to have_css(".ai-search-answer .d-skeleton")
    end

    it "only searches a query written in search syntax" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: '"small spaces"')

      expect(page).to have_css(
        ".search-menu .search-result-topic",
        text: "Gardening in small spaces",
      )
      expect(page).to have_no_css(".ai-search-answer")
      expect(request_ids).to be_empty
    end

    it "only searches when the top result is titled with the query" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "gardening in small spaces")

      expect(page).to have_css(
        ".search-menu .search-result-topic",
        text: "Gardening in small spaces",
      )
      expect(page).to have_no_css(".ai-search-answer")
      expect(request_ids).to be_empty
    end

    it "answers when the reader searches again on the same page" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "gardening")
      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")
      expect(request_ids).to be_empty

      # long enough after that it is a new search rather than the same one
      sleep 2.1
      find("#welcome-banner-search-input").fill_in(with: "spring gardening")

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(triggers.last).to eq(%w[pause searched_again])
    end

    it "does not count typing on after a pause as searching again" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "gardening")
      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")

      find("#welcome-banner-search-input").send_keys(" tips")

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(triggers.last).not_to eq(%w[pause searched_again])
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

      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")
      expect(find("#welcome-banner-search-input").value).to eq("gardening")
    end

    it "notes when enter asks for what a pause left out" do
      visit "/"
      wait_for_discoveries_channel

      find("#welcome-banner-search-input").fill_in(with: "gardening")
      expect(page).to have_css(".search-menu .search-result-topic", text: "Gardening tips")

      find("#welcome-banner-search-input").send_keys(:enter)

      try_until_success { expect(request_ids.size).to eq(1) }
      expect(triggers.last).to eq(%w[enter after_skip:places])
    end

    it "still answers on enter when people or places match" do
      visit "/"
      wait_for_discoveries_channel
      ask("gardening")

      expect(page).to have_css(".ai-search-answer .d-skeleton")
      expect(request_ids.size).to eq(1)
    end
  end
end
