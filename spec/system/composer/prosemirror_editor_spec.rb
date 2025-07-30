# frozen_string_literal: true

describe "Composer - ProseMirror editor", type: :system do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end
  fab!(:tag)

  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before { sign_in(current_user) }

  def open_composer
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus
  end

  def paste_and_click_image
    cdp.allow_clipboard
    cdp.copy_test_image
    cdp.paste
    rich.find(".composer-image-node img").click
  end

  it "hides the Composer container's preview button" do
    page.visit "/new-topic"

    expect(composer).to be_opened
    expect(composer).to have_no_composer_preview_toggle

    composer.toggle_rich_editor

    expect(composer).to have_composer_preview_toggle
  end

  it "saves the user's rich editor preference and remembers it when reopening the composer" do
    open_composer
    expect(composer).to have_rich_editor_active
    composer.toggle_rich_editor
    expect(composer).to have_markdown_editor_active

    try_until_success(frequency: 0.5) do
      expect(current_user.user_option.reload.composition_mode).to eq(
        UserOption.composition_mode_types[:markdown],
      )
    end

    visit("/")
    open_composer
    expect(composer).to have_markdown_editor_active
  end

  it "remembers the user's rich editor preference when starting a new PM" do
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    page.visit("/u/#{current_user.username}/messages")
    find(".new-private-message").click
    expect(composer).to be_opened
    expect(composer).to have_rich_editor_active
  end

  # TODO (martin) Remove this once we are sure all users have migrated
  # to the new rich editor preference, or a few months after the 3.5 release.
  it "saves the old keyValueStore editor preference to the database" do
    visit "/"

    page.execute_script "window.localStorage.setItem('discourse_d-editor-prefers-rich-editor', 'true');"

    expect(
      page.evaluate_script("window.localStorage.getItem('discourse_d-editor-prefers-rich-editor')"),
    ).to eq("true")

    open_composer

    expect(composer).to have_rich_editor

    try_until_success(frequency: 0.5) do
      expect(current_user.user_option.reload.composition_mode).to eq(
        UserOption.composition_mode_types[:rich],
      )
    end

    expect(
      page.evaluate_script(
        "window.localStorage.getItem('discourse_d-editor-prefers-rich-editor') === null",
      ),
    ).to eq(true)
  end

  context "with autocomplete" do
    it "triggers an autocomplete on mention" do
      open_composer
      composer.type_content("@#{current_user.username}")

      expect(composer).to have_mention_autocomplete
    end

    it "triggers an autocomplete on hashtag" do
      open_composer
      composer.type_content("##{tag.name}")

      expect(composer).to have_hashtag_autocomplete
    end

    it "triggers an autocomplete on emoji" do
      open_composer
      composer.type_content(":smile")

      expect(composer).to have_emoji_autocomplete
    end

    it "strips partially written emoji when using 'more' emoji modal" do
      open_composer

      composer.type_content("Why :repeat_single")

      expect(composer).to have_emoji_autocomplete

      # "more" emoji picker
      composer.send_keys(:down, :enter)
      find("img[data-emoji='repeat_single_button']").click
      composer.toggle_rich_editor

      expect(composer).to have_value("Why :repeat_single_button: ")
    end
  end

  context "with inputRules" do
    it "supports > to create a blockquote" do
      open_composer
      composer.type_content("> This is a blockquote")

      expect(rich).to have_css("blockquote", text: "This is a blockquote")
    end

    it "supports n. to create an ordered list" do
      open_composer
      composer.type_content("1. Item 1\n5. Item 2")

      expect(rich).to have_css("ol li", text: "Item 1")
      expect(find("ol ol", text: "Item 2")["start"]).to eq(5)
    end

    it "supports *, - or + to create an unordered list" do
      open_composer
      composer.type_content("* Item 1\n")
      composer.type_content("- Item 2\n")
      composer.type_content("+ Item 3")

      expect(rich).to have_css("ul ul li", count: 3)
    end

    it "uses 'tight' lists for both ordered and unordered lists by default" do
      open_composer
      composer.type_content("1. Item 1\n5. Item 2\n\n")
      composer.type_content("* Item 1\n* Item 2")
      expect(rich).to have_css("ol[data-tight='true']")
      expect(rich).to have_css("ul[data-tight='true']")
    end

    it "supports ``` or 4 spaces to create a code block" do
      open_composer
      composer.type_content("```\nThis is a code block")
      composer.send_keys(%i[shift enter])
      composer.type_content("    This is a code block")

      expect(rich).to have_css("pre code", text: "This is a code block", count: 2)
    end

    it "supports 1-6 #s to create a heading" do
      open_composer
      composer.type_content("# Heading 1\n")
      composer.type_content("## Heading 2\n")
      composer.type_content("### Heading 3\n")
      composer.type_content("#### Heading 4\n")
      composer.type_content("##### Heading 5\n")
      composer.type_content("###### Heading 6\n")

      expect(rich).to have_css("h1", text: "Heading 1")
      expect(rich).to have_css("h2", text: "Heading 2")
      expect(rich).to have_css("h3", text: "Heading 3")
      expect(rich).to have_css("h4", text: "Heading 4")
      expect(rich).to have_css("h5", text: "Heading 5")
      expect(rich).to have_css("h6", text: "Heading 6")
    end

    it "supports _ or * to create an italic text" do
      open_composer
      composer.type_content("_This is italic_\n")
      composer.type_content("Hey _This is italic_\n")
      composer.type_content("*This is italic*\n")
      composer.type_content("Hey*This is italic*\n")

      expect(rich).to have_css("em", text: "This is italic", count: 4)

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "*This is italic*\n\nHey *This is italic*\n\n*This is italic*\n\nHey*This is italic*",
      )
    end

    it "supports __ or ** to create a bold text" do
      open_composer
      composer.type_content("__This is bold__\n\n")
      composer.type_content("**This is bold**\n\n")
      composer.type_content("Hey __This is bold__\n\n")
      composer.type_content("Hey**This is bold**")

      expect(rich).to have_css("strong", text: "This is bold", count: 4)

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "**This is bold**\n\n**This is bold**\n\nHey **This is bold**\n\nHey**This is bold**",
      )
    end

    it "supports ` to create a code text" do
      open_composer
      composer.type_content("`This is code`")

      expect(rich).to have_css("code", text: "This is code")
    end

    it "supports typographer replacements" do
      open_composer
      composer.type_content(
        "foo +- bar... test???? wow!!!! x,, y-- --- a--> b<-- c-> d<- e<-> f<--> (tm) (pa)",
      )

      expect(rich).to have_css(
        "p",
        text: "foo ± bar… test??? wow!!! x, y– — a–> b←- c→ d← e←> f←→ ™ ¶",
      )
    end

    it "supports ---, ***, ___, en-dash+hyphen, em-dash+hyphen to create a horizontal rule" do
      open_composer
      composer.type_content("Hey\n---There\n*** Friend\n___ How\n\u2013-are\n\u2014-you")

      expect(rich).to have_css("hr", count: 5)
    end

    it "supports <http://example.com> to create an 'autolink'" do
      open_composer
      composer.type_content("<http://example.com>")

      expect(rich).to have_css("a", text: "http://example.com")

      composer.toggle_rich_editor

      expect(composer).to have_value("<http://example.com>")
    end
  end

  context "with oneboxing" do
    let(:cdp) { PageObjects::CDP.new }

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

  context "with keymap" do
    PLATFORM_KEY_MODIFIER = SystemHelpers::PLATFORM_KEY_MODIFIER
    it "supports Ctrl + B to create a bold text" do
      open_composer
      composer.type_content([PLATFORM_KEY_MODIFIER, "b"])
      composer.type_content("This is bold")

      expect(rich).to have_css("strong", text: "This is bold")
    end

    it "supports Ctrl + I to create an italic text" do
      open_composer
      composer.type_content([PLATFORM_KEY_MODIFIER, "i"])
      composer.type_content("This is italic")

      expect(rich).to have_css("em", text: "This is italic")
    end

    it "supports Ctrl + K to create a link" do
      hyperlink_modal = PageObjects::Modals::Base.new
      open_composer
      page.send_keys([PLATFORM_KEY_MODIFIER, "k"])
      expect(hyperlink_modal).to be_open
      expect(hyperlink_modal.header).to have_content(I18n.t("js.composer.link_dialog_title"))
      page.send_keys("https://www.example.com")
      page.send_keys(:tab)
      page.send_keys("This is a link")
      page.send_keys(:enter)

      expect(rich).to have_css("a", text: "This is a link")
    end

    it "supports Ctrl + Shift + 7 to create an ordered list" do
      open_composer
      composer.type_content("Item 1")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "7"])

      expect(rich).to have_css("ol li", text: "Item 1")
    end

    it "supports Ctrl + Shift + 8 to create a bullet list" do
      open_composer
      composer.type_content("Item 1")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "8"])

      expect(rich).to have_css("ul li", text: "Item 1")
    end

    it "supports Ctrl + Shift + 9 to create a blockquote" do
      open_composer
      composer.type_content("This is a blockquote")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "9"])

      expect(rich).to have_css("blockquote", text: "This is a blockquote")
    end

    it "supports Ctrl + Shift + 1-4 for headings, 0 for reset" do
      open_composer
      (1..4).each do |i|
        composer.type_content("\nHeading #{i}")
        composer.send_keys([PLATFORM_KEY_MODIFIER, :alt, i.to_s])

        expect(rich).to have_css("h#{i}", text: "Heading #{i}")
      end

      composer.send_keys([PLATFORM_KEY_MODIFIER, :alt, "0"])
      expect(rich).not_to have_css("h4")
    end

    it "supports Ctrl + Z and Ctrl + Shift + Z to undo and redo" do
      open_composer
      cdp.copy_paste("This is a test")
      composer.send_keys([PLATFORM_KEY_MODIFIER, "z"])

      expect(rich).not_to have_css("p", text: "This is a test")

      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "z"])

      expect(rich).to have_css("p", text: "This is a test")
    end

    it "supports Ctrl + Shift + _ to create a horizontal rule" do
      open_composer
      composer.type_content("This is a test")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "_"])

      expect(rich).to have_css("hr")
    end

    it "supports Backspace to reset a heading" do
      open_composer
      composer.type_content("# With text")

      expect(rich).to have_css("h1", text: "With text")

      composer.send_keys(:home)
      wait_for_timeout
      composer.send_keys(:backspace)

      expect(rich).to have_css("p", text: "With text")
    end

    it "supports Backspace to reset a code_block" do
      open_composer
      composer.type_content("```code block")
      composer.send_keys(:home)
      wait_for_timeout
      composer.send_keys(:backspace)

      expect(rich).to have_css("p", text: "code block")
    end

    it "doesn't add a new list item when backspacing from below a list" do
      open_composer
      composer.type_content("1. Item 1\nItem 2")
      composer.send_keys(:down)
      composer.type_content("Item 3")
      composer.send_keys(:home)
      composer.send_keys(:backspace)

      expect(rich).to have_css("ol li", text: "Item 1")
      expect(rich).to have_css("ol li", text: "Item 2Item 3")
    end

    it "supports Ctrl + M to toggle between rich and markdown editors" do
      open_composer

      composer.type_content("> This is a test")

      expect(composer).to have_value(nil)
      expect(rich).to have_css("blockquote", text: "This is a test")

      composer.send_keys([:control, "m"])

      expect(composer).to have_value("> This is a test")
      expect(composer).to have_no_rich_editor

      composer.send_keys([:control, "m"])

      expect(composer).to have_value(nil)
      expect(rich).to have_css("blockquote", text: "This is a test")
    end
  end

  describe "pasting content" do
    it "does not freeze the editor when pasting markdown code blocks without a language" do
      with_logs do |logger|
        open_composer

        # The example is a bit convoluted, but it's the simplest way to reproduce the issue.
        composer.type_content("This is a test\n\n")
        cdp.copy_paste <<~MARKDOWN
          ```
          puts SiteSetting.all_settings(filter_categories: ["uncategorized"]).map { |setting| setting[:setting] }.join("\n")
          ```
        MARKDOWN

        expect(logger.logs.map { |log| log[:message] }).not_to include(
          "Maximum call stack size exceeded",
        )
        expect(rich).to have_css("pre code")
        expect(rich).to have_css("select.code-language-select")
      end
    end

    it "parses images copied from cooked with base62-sha1" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste(
        '<img src="image.png" alt="alt text" data-base62-sha1="1234567890">',
        html: true,
      )

      expect(rich).to have_css(
        "img[src$='image.png'][alt='alt text'][data-orig-src='upload://1234567890']",
      )
    end

    it "respects existing marks when pasting a url over a selection" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("not selected `code`**bold**not*italic* not selected")
      rich.find("strong").double_click

      cdp.copy_paste("www.example.com")

      expect(rich).to have_css("code", text: "code")
      expect(rich).to have_css("strong", text: "bold")
      expect(rich).to have_css("em", text: "italic")

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "not selected [`code`**bold**not*italic*](www.example.com) not selected",
      )
    end

    it "auto-links pasted URLs from text/html over a selection" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste("not selected **bold** not selected")
      rich.find("strong").double_click

      cdp.copy_paste("<p>www.example.com</p>", html: true)

      composer.toggle_rich_editor

      expect(composer).to have_value("not selected **[bold](www.example.com)** not selected")
    end

    it "removes newlines from alt/title in pasted image" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste(<<~HTML, html: true)
        <img src="https://example.com/image.png" alt="alt
        with new
        lines" title="title
        with new
        lines">
      HTML

      img = rich.find(".composer-image-node img")

      expect(img["src"]).to eq("https://example.com/image.png")
      expect(img["alt"]).to eq("alt with new lines")
      expect(img["title"]).to eq("title with new lines")

      composer.toggle_rich_editor

      expect(composer).to have_value(
        '![alt with new lines](https://example.com/image.png "title with new lines")',
      )
    end

    xit "ignores text/html content if Files are present" do
      open_composer
      paste_and_click_image

      expect(rich).to have_css("img[data-orig-src]", count: 1)

      composer.focus # making sure the toggle click won't be captured as a double click
      composer.toggle_rich_editor

      expect(composer).to have_value("![image|244x66](upload://hGLky57lMjXvqCWRhcsH31ShzmO.png)")
    end

    it "should correctly merge text with link marks created from parsing" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste("This is a [link](https://example.com)")
      expect(rich).to have_css("a", text: "link")

      composer.type_content(:space)
      composer.type_content(:left)
      composer.type_content(:backspace)

      expect(rich).to have_css("a", text: "lin")
    end
  end

  describe "toolbar state updates" do
    it "updates the toolbar state following the cursor position" do
      open_composer

      expect(page).to have_css(".toolbar__button.bold.--active", count: 0)
      expect(page).to have_css(".toolbar__button.italic.--active", count: 0)
      expect(page).to have_css(".toolbar__button.heading.--active", count: 0)
      expect(page).to have_css(".toolbar__button.link.--active", count: 0)
      expect(page).to have_css(".toolbar__button.bullet.--active", count: 0)
      expect(page).to have_css(".toolbar__button.list.--active", count: 0)
      expect(page).to have_css(".toolbar__button.code.--active", count: 0)
      expect(page).to have_css(".toolbar__button.blockquote.--active", count: 0)

      composer.type_content("> - ` [***many styles***](https://example.com)`")
      composer.send_keys(:left, :left)

      expect(page).to have_css(".toolbar__button.bold.--active", count: 1)
      expect(page).to have_css(".toolbar__button.italic.--active", count: 1)
      expect(page).to have_css(".toolbar__button.link.--active", count: 1)
      expect(page).to have_css(".toolbar__button.bullet.--active", count: 1)
      expect(page).to have_css(".toolbar__button.list.--active", count: 0)
      expect(page).to have_css(".toolbar__button.code.--active", count: 1)
      expect(page).to have_css(".toolbar__button.blockquote.--active", count: 1)

      page.find(".toolbar__button.bullet").click
      page.find(".toolbar__button.list").click

      expect(page).to have_css(".toolbar__button.list.--active", count: 1)
      expect(page).to have_css(".toolbar__button.bullet.--active", count: 0)
    end
  end

  describe "trailing paragraph" do
    it "ensures there is always a trailing paragraph" do
      open_composer

      expect(rich).to have_css("p", count: 1)
      composer.type_content("This is a test")

      expect(rich).to have_css("p", count: 1)
      expect(rich).to have_css("p", text: "This is a test", count: 1)

      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "_"]) # Insert a horizontal rule
      expect(rich).to have_css("hr", count: 1)
      expect(rich).to have_css("p", count: 2) # New paragraph inserted after the ruler
    end
  end

  describe "auto-linking/unlinking while typing" do
    it "auto-links non-protocol URLs and removes the link when no longer a URL" do
      open_composer

      composer.type_content("www.example.com and also mid-paragraph www.example2.com")

      expect(rich).to have_css("a", text: "www.example.com")
      expect(rich).to have_css("a", text: "www.example2.com")
      expect(rich).to have_css("a", count: 2)

      composer.send_keys(:backspace)
      composer.send_keys(:backspace)

      expect(rich).to have_css("a", count: 1)

      composer.type_content("om")

      expect(rich).to have_css("a", text: "www.example2.com")
    end

    it "auto-links protocol URLs" do
      open_composer

      composer.type_content("https://example.com")

      expect(rich).to have_css("a", text: "https://example.com")

      composer.send_keys(:backspace)
      composer.send_keys(:backspace)

      expect(rich).to have_css("a", text: "https://example.c")
    end

    it "doesn't auto-link immediately following a `" do
      open_composer

      composer.type_content("`https://example.com`")

      expect(rich).to have_css("code", text: "https://example.com")
      expect(rich).to have_no_css("a", text: "https://example.com")
    end

    it "doesn't auto-link within code marks" do
      open_composer

      composer.type_content("`code mark`")
      composer.send_keys(:left)

      composer.type_content(" https://example.com")

      expect(rich).to have_css("code", text: "code mark https://example.com")
      expect(rich).to have_no_css("a", text: "https://example.com")
    end

    it "doesn't continue a <https://url> markup='autolink'" do
      open_composer

      composer.type_content("<https://example.com>.de")

      expect(rich).to have_css("a", text: "https://example.com")
      expect(rich).to have_no_css("a", text: "https://example.com.de")

      composer.toggle_rich_editor

      expect(composer).to have_value("<https://example.com>.de")
    end
  end

  describe "uploads" do
    it "handles uploads and disables the editor toggle while uploading" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(composer).to have_in_progress_uploads
        expect(composer.editor_toggle_switch).to be_disabled
      end

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_css("img:not(.ProseMirror-separator)", count: 1)
    end
  end

  describe "code marks with fake cursor" do
    it "allows typing after a code mark with/without the mark" do
      open_composer

      composer.type_content("This is ~~SPARTA!~~ `code!`.")

      expect(rich).to have_css("code", text: "code!")

      # within the code mark
      composer.send_keys(:backspace)
      composer.send_keys(:backspace)
      composer.type_content("!")

      expect(rich).to have_css("code", text: "code!")

      # after the code mark
      composer.send_keys(:right)
      composer.type_content(".")

      composer.toggle_rich_editor

      expect(composer).to have_value("This is ~~SPARTA!~~ `code!`.")
    end

    xit "allows typing before a code mark with/without the mark" do
      open_composer

      composer.type_content("`code mark`")

      expect(rich).to have_css("code", text: "code mark")

      # before the code mark
      composer.send_keys(:home)
      composer.send_keys(:left)
      composer.type_content("..")

      # within the code mark
      composer.send_keys(:right)
      composer.type_content("!!")

      composer.toggle_rich_editor

      expect(composer).to have_value("..`!!code mark`")
    end
  end

  describe "emojis" do
    it "has the only-emoji class if 1-3 emojis are 'alone'" do
      open_composer

      composer.type_content("> :smile: ")

      expect(rich).to have_css(".only-emoji", count: 1)

      composer.type_content(":P ")

      expect(rich).to have_css(".only-emoji", count: 2)

      composer.type_content(":D ")

      expect(rich).to have_css(".only-emoji", count: 3)

      composer.type_content("Hey!")

      expect(rich).to have_no_css(".only-emoji")
    end

    it "preserves formatting marks when replacing text with emojis using :code: pattern" do
      open_composer

      composer.type_content("**bold :smile:**")

      expect(rich).to have_css("strong img.emoji")
      expect(rich).to have_css("strong", text: "bold")

      composer.toggle_rich_editor
      expect(composer).to have_value("**bold :smile:**")
    end

    it "preserves formatting marks when replacing text with emojis using text shortcuts" do
      open_composer

      composer.type_content("*italics :) *")

      expect(rich).to have_css("em img.emoji")
      expect(rich).to have_css("em", text: "italics")

      composer.toggle_rich_editor
      expect(composer).to have_value("*italics :slight_smile:* ")
    end

    it "preserves link marks when replacing text with emojis" do
      open_composer

      composer.type_content("[link text :heart:](https://example.com)")

      expect(rich).to have_css("a img.emoji")
      expect(rich).to have_css("a", text: "link text")

      composer.toggle_rich_editor
      expect(composer).to have_value("[link text :heart:](https://example.com)")
    end
  end

  describe "with mentions" do
    fab!(:post)
    fab!(:topic) { post.topic }
    fab!(:mixed_case_user) { Fabricate(:user, username: "TestUser_123") }
    fab!(:mixed_case_group) do
      Fabricate(:group, name: "TestGroup_ABC", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    end

    before do
      Draft.set(
        current_user,
        topic.draft_key,
        0,
        { reply: "hey @#{current_user.username} and @unknown - how are you?" }.to_json,
      )
    end

    it "validates manually typed mentions" do
      open_composer

      composer.type_content("Hey @#{current_user.username} ")

      expect(rich).to have_css("a.mention", text: current_user.username)

      composer.type_content("and @invalid_user - how are you?")

      expect(rich).to have_no_css("a.mention", text: "@invalid_user")

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "Hey @#{current_user.username} and @invalid_user - how are you?",
      )
    end

    it "validates mentions in drafts" do
      page.visit("/t/#{topic.id}")

      expect(composer).to be_opened

      expect(rich).to have_css("a.mention", text: current_user.username)
      expect(rich).to have_no_css("a.mention", text: "@unknown")
    end

    it "validates mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testuser_123 and @TESTUSER_123 ")

      expect(rich).to have_css("a.mention", text: "testuser_123")
      expect(rich).to have_css("a.mention", text: "TESTUSER_123")

      composer.type_content("and @InvalidUser ")

      expect(rich).to have_no_css("a.mention", text: "@InvalidUser")
    end

    it "validates group mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testgroup_abc and @TESTGROUP_ABC ")

      expect(rich).to have_css("a.mention", text: "testgroup_abc")
      expect(rich).to have_css("a.mention", text: "TESTGROUP_ABC")

      composer.type_content("and @InvalidGroup ")

      expect(rich).to have_no_css("a.mention", text: "@InvalidGroup")
    end

    describe "with unicode usernames" do
      fab!(:category)

      before do
        SiteSetting.external_system_avatars_enabled = true
        SiteSetting.external_system_avatars_url =
          "/letter_avatar_proxy/v4/letter/{first_letter}/{color}/{size}.png"
        SiteSetting.unicode_usernames = true
      end

      it "renders unicode mentions as nodes" do
        unicode_user = Fabricate(:unicode_user)

        open_composer

        composer.type_content("Hey @#{unicode_user.username} - how are you?")

        expect(rich).to have_css("a.mention", text: unicode_user.username)

        composer.toggle_rich_editor

        expect(composer).to have_value("Hey @#{unicode_user.username} - how are you?")
      end
    end
  end

  describe "link toolbar" do
    let(:upsert_hyperlink_modal) { PageObjects::Modals::UpsertHyperlink.new }

    it "shows link toolbar when cursor is on a link" do
      open_composer

      composer.type_content("[Example](https://example.com)")
      composer.send_keys(:left, :left, :left)

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_css("button.composer-link-toolbar__edit")
      expect(page).to have_css("button.composer-link-toolbar__copy")
      expect(page).to have_css("a.composer-link-toolbar__visit", text: "example.com")
    end

    it "allows editing a link via toolbar" do
      cdp.allow_clipboard
      open_composer

      composer.type_content("[Example](https://example.com)")
      composer.send_keys(:left, :left, :left)

      # Use Tab to navigate to the toolbar and Enter to activate edit
      composer.send_keys(:tab, :enter)

      expect(upsert_hyperlink_modal).to be_open

      expect(upsert_hyperlink_modal.link_text_value).to eq("Example")
      expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")

      upsert_hyperlink_modal.fill_in_link_text("Updated Example")
      upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com")
      upsert_hyperlink_modal.send_enter_link_text

      expect(rich).to have_css("a[href='https://updated-example.com']", text: "Updated Example")

      composer.toggle_rich_editor
      expect(composer).to have_value("[Updated Example](https://updated-example.com)")
    end

    it "escapes URL when editing link via modal" do
      cdp.allow_clipboard
      open_composer

      composer.type_content("[Example](https://example.com)")
      composer.send_keys(:left, :left, :left)

      # Use Tab to navigate to the toolbar and Enter to activate edit
      composer.send_keys(:tab, :enter)

      expect(upsert_hyperlink_modal).to be_open

      expect(upsert_hyperlink_modal.link_text_value).to eq("Example")
      expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")

      upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com?query=with space")
      upsert_hyperlink_modal.click_primary_button

      expect(rich).to have_css(
        "a[href='https://updated-example.com?query=with%20space']",
        text: "Example",
      )
    end

    it "allows copying a link URL via toolbar" do
      cdp.allow_clipboard
      open_composer

      composer.type_content("[Example](https://example.com)")
      composer.send_keys(:left, :left, :left)

      find("button.composer-link-toolbar__copy").click

      expect(page).to have_content(I18n.t("js.composer.link_toolbar.link_copied"))
    end

    it "allows unlinking a link via toolbar when markup is not auto or linkify" do
      open_composer

      composer.type_content("[Manual Link](https://example.com)")

      find("button.composer-link-toolbar__unlink").click

      expect(rich).to have_no_css("a")
      expect(rich).to have_content("Manual Link")

      composer.toggle_rich_editor
      expect(composer).to have_value("Manual Link")
    end

    it "doesn't show unlink button for auto-detected links" do
      open_composer

      composer.type_content("<https://example.com>")

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_no_css("button.composer-link-toolbar__unlink")
      expect(page).to have_css("a.composer-link-toolbar__visit", text: "")
    end

    it "doesn't show unlink button for auto-linkified URLs" do
      open_composer

      composer.type_content("https://example.com")

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_no_css("button.composer-link-toolbar__unlink")
      expect(page).to have_css("a.composer-link-toolbar__visit", text: "")
    end

    it "shows visit button for valid URLs" do
      open_composer

      composer.type_content("[Example](https://example.com)")

      expect(page).to have_css(
        "a.composer-link-toolbar__visit[href='https://example.com']",
        text: "example.com",
      )
    end

    it "strips base URL from internal links in toolbar display" do
      open_composer

      internal_link = "#{Discourse.base_url}/t/some-topic/123"

      composer.type_content("[Internal Link](#{internal_link})")
      composer.send_keys(:left, :left, :left)

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_css(
        "a.composer-link-toolbar__visit[href='#{internal_link}']",
        text: "/t/some-topic/123",
      )
    end

    it "doesn't show visit button for invalid URLs" do
      open_composer

      composer.type_content("[Example](not-a-url)")

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_no_css("a.composer-link-toolbar__visit")
      expect(page).to have_no_css(".composer-link-toolbar__divider")
    end

    it "closes toolbar when cursor moves outside link" do
      open_composer

      composer.type_content("Text before [Example](https://example.com),")

      composer.send_keys(:left)

      expect(page).to have_css("[data-identifier='composer-link-toolbar']")
      expect(page).to have_css("a.composer-link-toolbar__visit", text: "example.com")

      composer.send_keys(:right)

      expect(page).to have_no_css("[data-identifier='composer-link-toolbar']")
    end

    it "preserves emojis when editing a link via toolbar" do
      open_composer

      composer.type_content("[Party :tada: Time](https://example.com)")
      composer.send_keys(:left, :left, :left)

      # Use Tab to navigate to the toolbar and Enter to activate edit
      composer.send_keys(:tab, :enter)

      expect(upsert_hyperlink_modal).to be_open

      expect(upsert_hyperlink_modal.link_text_value).to eq("Party :tada: Time")
      expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")

      upsert_hyperlink_modal.fill_in_link_text("Updated :tada: Party")
      upsert_hyperlink_modal.fill_in_link_url("https://updated-party.com")
      upsert_hyperlink_modal.click_primary_button

      expect(rich).to have_css("a[href='https://updated-party.com']")
      expect(rich).to have_css("a img[title=':tada:'], a img[alt=':tada:']")

      composer.toggle_rich_editor
      expect(composer).to have_value("[Updated :tada: Party](https://updated-party.com)")
    end

    it "preserves bold and italic formatting when editing a link via toolbar" do
      open_composer

      composer.type_content("[**Bold** and *italic* text](https://example.com)")
      composer.send_keys(:left, :left, :left)

      # Use Tab to navigate to the toolbar and Enter to activate edit
      composer.send_keys(:tab, :enter)

      expect(upsert_hyperlink_modal).to be_open

      expect(upsert_hyperlink_modal.link_text_value).to eq("**Bold** and *italic* text")
      expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")

      upsert_hyperlink_modal.fill_in_link_text("Updated **bold** and *italic* content")
      upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com")
      upsert_hyperlink_modal.click_primary_button

      expect(rich).to have_css("a[href='https://updated-example.com']")
      expect(rich).to have_css("strong a", text: "bold")
      expect(rich).to have_css("em a", text: "italic")

      composer.toggle_rich_editor
      expect(composer).to have_value(
        "[Updated **bold** and *italic* content](https://updated-example.com)",
      )
    end
  end

  describe "image toolbar" do
    it "allows scaling image down and up via toolbar" do
      open_composer
      paste_and_click_image

      find(".composer-image-toolbar__zoom-out").click

      expect(rich).to have_selector(".composer-image-node img[data-scale='75']")

      find(".composer-image-toolbar__zoom-out").click

      expect(rich).to have_selector(".composer-image-node img[data-scale='50']")

      find(".composer-image-toolbar__zoom-in").click

      expect(rich).to have_selector(".composer-image-node img[data-scale='75']")

      find(".composer-image-toolbar__zoom-in").click

      expect(rich).to have_selector(".composer-image-node img[data-scale='100']")
    end

    it "allows removing image via toolbar" do
      open_composer
      composer.type_content("Before")
      paste_and_click_image

      find(".composer-image-toolbar__trash").click

      expect(rich).to have_no_css(".composer-image-node img")
      expect(rich).to have_content("Before")
    end

    it "hides toolbar when clicking outside image" do
      open_composer
      paste_and_click_image

      expect(page).to have_css("[data-identifier='composer-image-toolbar']")

      rich.find("p").click

      expect(page).to have_no_css("[data-identifier='composer-image-toolbar']")
    end

    it "sets width and height attributes when scaling external images" do
      open_composer

      image = Fabricate(:image_upload)

      composer.type_content("![alt text](#{image.url})")

      find(".composer-image-node img").click

      expect(rich).to have_no_css(".composer-image-node img[width]")
      expect(rich).to have_no_css(".composer-image-node img[height]")

      find(".composer-image-toolbar__zoom-out").click

      expect(rich).to have_css(".composer-image-node img[width]")
      expect(rich).to have_css(".composer-image-node img[height]")
    end
  end

  describe "image alt text display and editing" do
    it "shows alt text input when image is selected" do
      open_composer
      paste_and_click_image

      expect(page).to have_css("[data-identifier='composer-image-alt-text']")
      expect(page).to have_css(".image-alt-text-input__display")
    end

    it "allows editing alt text by clicking on display" do
      open_composer
      paste_and_click_image

      find(".image-alt-text-input__display").click

      expect(page).to have_css(".image-alt-text-input.--expanded")
      expect(page).to have_css(".image-alt-text-input__field")

      find(".image-alt-text-input__field").fill_in(with: "updated alt text")
      find(".image-alt-text-input__field").send_keys(:enter)

      expect(rich.find(".composer-image-node img")["alt"]).to eq("updated alt text")
    end

    it "saves alt text when leaving the input field" do
      open_composer
      paste_and_click_image

      find(".image-alt-text-input__display").click
      find(".image-alt-text-input__field").fill_in(with: "new alt text")

      rich.find("p").click

      expect(rich.find(".composer-image-node img")["alt"]).to eq("new alt text")
    end

    it "displays the placeholder if alt text is empty" do
      open_composer
      paste_and_click_image

      expect(page).to have_css(".image-alt-text-input__display", text: "image")

      find(".image-alt-text-input__display").click
      find(".image-alt-text-input__field").fill_in(with: "")
      find(".image-alt-text-input__field").send_keys(:enter)

      expect(page).to have_css(
        ".image-alt-text-input__display",
        text: I18n.t("js.composer.image_alt_text.title"),
      )
    end
  end

  describe "heading toolbar" do
    it "updates toolbar active state and icon based on current heading level" do
      open_composer

      composer.type_content("## This is a test\n#### And this is another test")
      expect(page).to have_css(".toolbar__button.heading.--active", count: 1)
      expect(find(".toolbar__button.heading")).to have_css(".d-icon-discourse-h4")

      composer.send_keys(:up)
      expect(page).to have_css(".toolbar__button.heading.--active", count: 1)
      expect(find(".toolbar__button.heading")).to have_css(".d-icon-discourse-h2")

      composer.select_all
      expect(page).to have_no_css(".toolbar__button.heading.--active")
      expect(find(".toolbar__button.heading")).to have_css(".d-icon-discourse-text")
    end

    it "puts a check next to current heading level in toolbar dropdown, or no check if multiple formats are selected" do
      open_composer

      composer.type_content("## This is a test\n#### And this is another test")

      heading_menu = composer.heading_menu
      heading_menu.expand
      expect(heading_menu.option("[data-name='heading-4']")).to have_css(".d-icon-check")
      heading_menu.collapse

      composer.select_range_rich_editor(0, 0)
      heading_menu.expand
      expect(heading_menu.option("[data-name='heading-2']")).to have_css(".d-icon-check")
      heading_menu.collapse

      composer.select_all
      heading_menu.expand
      expect(heading_menu.option("[data-name='heading-2']")).to have_no_css(".d-icon-check")
      expect(heading_menu.option("[data-name='heading-4']")).to have_no_css(".d-icon-check")
    end

    it "can change heading level or reset to paragraph" do
      open_composer

      composer.type_content("This is a test")
      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click

      expect(rich).to have_css("h2", text: "This is a test")

      heading_menu.expand
      heading_menu.option("[data-name='heading-3']").click
      expect(rich).to have_css("h3", text: "This is a test")

      heading_menu.expand
      heading_menu.option("[data-name='heading-paragraph']").click
      expect(rich).to have_css("p", text: "This is a test")
    end

    it "can insert a heading on an empty line" do
      open_composer

      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click

      composer.type_content("This is a test")
      expect(rich).to have_css("h2", text: "This is a test")
    end
  end
end
