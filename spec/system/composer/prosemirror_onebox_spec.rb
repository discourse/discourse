# frozen_string_literal: true

describe "Composer - ProseMirror - Oneboxing", type: :system do
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

    expect(rich).to have_css(
      "a.inline-onebox[href='https://example.com/x']",
      text: "Example Site 1",
    )

    composer.type_content("in the middle of text")
    composer.toggle_rich_editor

    expect(composer).to have_value(
      "Check out this link https://example.com/x in the middle of text",
    )
  end

  it "creates a full onebox for standalone links" do
    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("https://example.com")
    page.send_keys(:enter)

    expect(rich).to have_css("div.onebox-wrapper[data-onebox-src='https://example.com']")
    expect(rich).to have_content("Example Site 1")
    expect(rich).to have_content("This is an example site")

    composer.toggle_rich_editor

    expect(composer).to have_value("https://example.com\n\n")
  end

  it "creates an inline onebox for links that are part of a paragraph" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("Some text ")
    cdp.copy_paste("https://example.com/x")
    composer.type_content(:space)

    expect(rich).to have_no_css("div.onebox-wrapper")
    expect(rich).to have_css("a.inline-onebox", text: "Example Site 1")

    composer.type_content("more text")
    composer.toggle_rich_editor

    expect(composer).to have_value("Some text https://example.com/x more text")
  end

  it "does not create oneboxes inside code blocks" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("```")
    cdp.copy_paste("https://example.com")

    expect(rich).to have_css("pre code")
    expect(rich).to have_no_css("div.onebox-wrapper")
    expect(rich).to have_no_css("a.inline-onebox")
    expect(rich).to have_content("https://example.com")

    composer.toggle_rich_editor

    expect(composer).to have_value("```\nhttps://example.com\n```")
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

    expect(rich).to have_css("a.inline-onebox", count: 6)
    expect(rich).to have_css(
      "a.inline-onebox[href='https://example.com/x']",
      text: "Example Site 1",
    )
    expect(rich).to have_css(
      "a.inline-onebox[href='https://example2.com/x']",
      text: "Example Site 2",
    )
    expect(rich).to have_css(
      "a.inline-onebox[href='https://example3.com/x']",
      text: "Example Site 3",
    )

    expect(rich).to have_css("div.onebox-wrapper", count: 6)
    expect(rich).to have_css("div.onebox-wrapper[data-onebox-src='https://example.com']")
    expect(rich).to have_css("div.onebox-wrapper[data-onebox-src='https://example2.com']")
    expect(rich).to have_css("div.onebox-wrapper[data-onebox-src='https://example3.com']")

    composer.toggle_rich_editor

    expect(composer).to have_value(markdown[0..-2])
  end

  xit "creates inline oneboxes for repeated links in different paste events" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("Hey ")
    cdp.copy_paste("https://example.com/x")
    composer.type_content(:space).type_content("and").type_content(:space)
    cdp.paste
    composer.type_content(:enter)

    expect(rich).to have_css(
      "a.inline-onebox[href='https://example.com/x']",
      text: "Example Site 1",
      count: 2,
    )

    composer.toggle_rich_editor

    expect(composer).to have_value("Hey https://example.com/x and https://example.com/x")
  end
end
