# frozen_string_literal: true

describe "Composer - ProseMirror - Quotes", type: :system do
  include_context "with prosemirror editor"

  it "keeps the cursor outside quote when pasted" do
    open_composer

    markdown = "[quote]\nThis is a quote\n\n[/quote]"
    cdp.copy_paste(markdown)
    composer.type_content("This is a test")

    composer.toggle_rich_editor

    expect(composer).to have_value(markdown + "\n\nThis is a test")
  end

  # TODO: Failing often https://github.com/discourse/discourse/actions/runs/16891573420/job/47852388890
  xit "lifts the first paragraph out of the quote with Backspace" do
    open_composer

    composer.type_content("[quote]Text")
    expect(rich).to have_css("aside.quote blockquote p", text: "Text")

    composer.send_keys(:home)
    composer.send_keys(:backspace)

    expect(rich).to have_no_css("aside.quote")
    expect(rich).to have_css("p", text: "Text")
  end

  it "breaks out of the quote with a double Enter" do
    open_composer

    composer.type_content("[quote]Inside")
    composer.send_keys(:enter)
    composer.send_keys(:enter)
    composer.type_content("Outside")

    expect(rich).to have_css("aside.quote blockquote p", text: "Inside")
    expect(rich).to have_css("aside.quote + p", text: "Outside")
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

    expect(rich).to have_css("aside.quote blockquote p", text: "This is a quote with a link: ")
    expect(rich).to have_css(
      "aside.quote blockquote p a[href='https://example.com']",
      text: "https://example.com",
    )
    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 1")
    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 2")
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

    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 1")
    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 2")
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

    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 1")
    expect(rich).to have_css("aside.quote blockquote ul li", text: "Item 2")
    expect(rich).to have_css("aside.quote blockquote p", text: "This is some post-list text.")
    expect(rich).to have_css("aside.quote blockquote pre code", text: 'puts "and some code"')
  end
end
