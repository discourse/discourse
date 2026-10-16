# frozen_string_literal: true

describe "Composer - ProseMirror - Oneboxing" do
  include_context "with prosemirror editor"

  before do
    def body(title)
      <<~HTML
      <html>
        <head>
          <title>#{title}</title>
          <meta property="og:title" content="#{title}">
          <meta property="og:description" content="This is an example site">
        </head>
        <body>
          <h1>#{title}</h1>
          <p>This domain is for use in examples.</p>
        </body>
      </html>
    HTML
    end

    stub_request(:head, %r{https://example\.com.*}).to_return(status: 200)
    stub_request(:get, %r{https://example\.com.*}).to_return(
      status: 200,
      body: body("Example Site 1"),
    )

    stub_request(:head, %r{https://example2\.com.*}).to_return(status: 200)
    stub_request(:get, %r{https://example2\.com.*}).to_return(
      status: 200,
      body: body("Example Site 2"),
    )

    stub_request(:head, %r{https://example3\.com.*}).to_return(status: 200)
    stub_request(:get, %r{https://example3\.com.*}).to_return(
      status: 200,
      body: body("Example Site 3"),
    )
  end

  it "creates an inline onebox for links within text" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("Check out this link ")
    cdp.copy_paste("https://example.com/x")
    composer.type_content(:space)

    expect(
      rich.locator("a.inline-onebox[href='https://example.com/x']").filter(visible: true),
    ).to contain_text([browser_text_pattern("Example Site 1")], useInnerText: true)

    composer.type_content("in the middle of text")
    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value(
      "Check out this link https://example.com/x in the middle of text",
    )
  end

  it "creates a full onebox for standalone links" do
    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("https://example.com")
    browser_page.keyboard.press("Enter")

    expect(
      rich.locator("div.onebox-wrapper[data-onebox-src='https://example.com']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(rich).to contain_text(browser_text_pattern("Example Site 1"), useInnerText: true)
    expect(rich).to contain_text(
      browser_text_pattern("This is an example site"),
      useInnerText: true,
    )

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("https://example.com")
  end

  it "creates an inline onebox for links that are part of a paragraph" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("Some text ")
    cdp.copy_paste("https://example.com/x")
    composer.type_content(:space)

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("div.onebox-wrapper")
        .filter(visible: true),
    ).to have_count(0)
    expect(rich.locator("a.inline-onebox").filter(visible: true)).to contain_text(
      [browser_text_pattern("Example Site 1")],
      useInnerText: true,
    )

    composer.type_content("more text")
    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("Some text https://example.com/x more text")
  end

  it "does not create oneboxes inside code blocks" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("```")
    cdp.copy_paste("https://example.com")

    expect(rich.locator("pre code").filter(visible: true)).not_to have_count(0)
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("div.onebox-wrapper")
        .filter(visible: true),
    ).to have_count(0)
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("a.inline-onebox")
        .filter(visible: true),
    ).to have_count(0)
    expect(rich).to contain_text(browser_text_pattern("https://example.com"), useInnerText: true)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("```\nhttps://example.com\n```")
  end

  it "creates oneboxes for mixed content" do
    cdp.allow_clipboard
    open_composer
    markdown = <<~MARKDOWN
    https://example.com

    Check this https://example.com/x and see if it fits you

    https://example2.com

    An inline to https://example2.com/x with text around it

    https://example3.com

    Another one for https://example3.com/x then

    https://example.com

    Phew, repeating https://example.com/x now

    https://example2.com

    And some text again https://example2.com/x

    https://example3.com/x

    Ok, that is it https://example3.com/x
    After a hard break
  MARKDOWN
    cdp.copy_paste(markdown)

    expect(rich.locator("a.inline-onebox").filter(visible: true)).to have_count(6)
    expect(
      rich.locator("a.inline-onebox[href='https://example.com/x']").filter(visible: true),
    ).to contain_text([browser_text_pattern("Example Site 1")], useInnerText: true)
    expect(
      rich.locator("a.inline-onebox[href='https://example2.com/x']").filter(visible: true),
    ).to contain_text([browser_text_pattern("Example Site 2")], useInnerText: true)
    expect(
      rich.locator("a.inline-onebox[href='https://example3.com/x']").filter(visible: true),
    ).to contain_text([browser_text_pattern("Example Site 3")], useInnerText: true)

    expect(rich.locator("div.onebox-wrapper").filter(visible: true)).to have_count(6)
    expect(
      rich.locator("div.onebox-wrapper[data-onebox-src='https://example.com']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(
      rich.locator("div.onebox-wrapper[data-onebox-src='https://example2.com']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(
      rich.locator("div.onebox-wrapper[data-onebox-src='https://example3.com']").filter(
        visible: true,
      ),
    ).not_to have_count(0)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value(markdown[0..-2])
  end

  it "creates inline oneboxes for repeated links in different paste events" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("Hey ")
    cdp.copy_paste("https://example.com/x")
    composer.type_content(:space).type_content("and").type_content(:space)
    cdp.paste
    composer.type_content(:enter)

    expect(
      rich
        .locator("a.inline-onebox[href='https://example.com/x']")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("Example Site 1")),
    ).to have_count(2)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value(
      "Hey https://example.com/x and https://example.com/x",
    )
  end

  it "removes loading decoration when onebox fetch fails" do
    # A blank preview makes /onebox respond 404, so the request rejects instead
    # of resolving to an error card.
    Oneboxer.stubs(:preview).returns("")

    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("https://example.com/fail")
    browser_page.keyboard.press("Enter")

    expect(rich.locator(".onebox-loading").filter(visible: true)).not_to have_count(0)
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator(".onebox-loading")
        .filter(visible: true),
    ).to have_count(0)
    expect(
      rich.locator("a[href='https://example.com/fail']").filter(visible: true),
    ).not_to have_count(0)
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator(".onebox-wrapper")
        .filter(visible: true),
    ).to have_count(0)
  end

  context "with watched word links" do
    fab!(:topic) { Fabricate(:topic, user: current_user) }
    fab!(:post) do
      Fabricate(:post, topic:, user: current_user, raw: "Check out discourse for more info")
    end
    fab!(:watched_word) do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:link],
        word: "discourse",
        replacement: "https://example.com/x",
      )
    end

    it "does not apply watched word links to the raw content" do
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".post-action-menu__edit").filter(visible: true).click
      expect(composer).to be_opened
      composer.focus

      expect(rich).to contain_text(browser_text_pattern("discourse"), useInnerText: true)
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a[href='https://example.com/x']")
          .filter(visible: true),
      ).to have_count(0)

      composer.toggle_rich_editor

      expect(composer).to RSpecPredicates.have_value("Check out discourse for more info")
    end
  end
end
