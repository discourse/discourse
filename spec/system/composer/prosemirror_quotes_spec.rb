# frozen_string_literal: true

describe "Composer - ProseMirror - Quotes" do
  include_context "with prosemirror editor"

  it "keeps the cursor outside quote when pasted" do
    open_composer

    markdown = "[quote]\nThis is a quote\n\n[/quote]"
    cdp.copy_paste(markdown)
    composer.type_content("This is a test")

    composer.toggle_rich_editor

    expect(composer).to have_value(markdown + "\n\nThis is a test")
  end

  it "lifts the first paragraph out of the quote with Backspace" do
    open_composer

    composer.type_content("[quote]Text")
    expect(
      rich.locator("aside.quote blockquote p").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Text")], useInnerText: true)

    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    wait_for_timeout # wait for the caret move
    browser_page.keyboard.press("Backspace")

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("aside.quote")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Text")],
      useInnerText: true,
    )
  end

  it "breaks out of the quote with a double Enter" do
    open_composer

    composer.type_content("[quote]Inside")
    browser_page.keyboard.press("Enter")
    browser_page.keyboard.press("Enter")
    composer.type_content("Outside")

    expect(
      rich.locator("aside.quote blockquote p").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Inside")], useInnerText: true)
    expect(
      rich.locator("aside.quote + p").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Outside")], useInnerText: true)
  end

  it "converts quotes with mixed content into the correct HTML" do
    cdp.allow_clipboard
    open_composer

    cdp.copy_paste(<<~QUOTE)
      [quote="john, post:1, topic:1"]
      This is a quote with a link: https://example.com

      And also a list:

      * Item 1
      * Item 2
      [/quote]
      QUOTE

    expect(
      rich.locator("aside.quote blockquote p").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("This is a quote with a link: ")],
      useInnerText: true,
    )
    expect(
      rich.locator("aside.quote blockquote p a[href='https://example.com']").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("https://example.com")],
      useInnerText: true,
    )
    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 1")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 2")], useInnerText: true)
  end

  it "converts quotes with only a list into the correct HTML" do
    cdp.allow_clipboard
    open_composer

    cdp.copy_paste(<<~QUOTE)
      [quote="john, post:1, topic:1"]
      * Item 1
      * Item 2
      [/quote]
      QUOTE

    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 1")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 2")], useInnerText: true)
  end

  it "converts quotes that start with a list into the correct HTML" do
    cdp.allow_clipboard
    open_composer

    cdp.copy_paste(<<~QUOTE)
      [quote="john, post:1, topic:1"]
      * Item 1
      * Item 2

      This is some post-list text.

      ```ruby
      puts "and some code"
      ```
      [/quote]
      QUOTE

    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 1")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote ul li").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Item 2")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote p").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("This is some post-list text.")],
      useInnerText: true,
    )
    expect(
      rich.locator("aside.quote blockquote pre code").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern('puts "and some code"')],
      useInnerText: true,
    )
  end
end
