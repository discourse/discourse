# frozen_string_literal: true

describe "Composer - ProseMirror - Pasting content", type: :system do
  include_context "with prosemirror editor"

  it "creates a mention when pasting an HTML anchor with class mention" do
    cdp.allow_clipboard
    open_composer
    html = %(<a href="/u/#{current_user.username}" class="mention">@#{current_user.username}</a>)
    cdp.copy_paste(html, html: true)
    expect(rich).to have_css("a.mention", text: current_user.username)
    expect(rich).to have_css("a.mention[data-name='#{current_user.username}']")
    expect(rich).to have_no_css("a.mention[href]")
    composer.toggle_rich_editor
    expect(composer).to have_value("@#{current_user.username}")
  end

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
    cdp.copy_paste('<img src="image.png" alt="alt text" data-base62-sha1="1234567890">', html: true)
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
    paste_and_click_image(cdp)
    expect(rich).to have_css("img[data-orig-src]", count: 1)
    composer.focus # making sure the toggle click won't be captured as a double click
    composer.toggle_rich_editor
    expect(composer).to have_value("![image|244x66](upload://hGLky57lMjXvqCWRhcsH31ShzmO.png)")
  end

  it "handles multiple data URI images pasted simultaneously" do
    SiteSetting.simultaneous_uploads = 1
    valid_png_data_uri =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
    valid_jpeg_data_uri =
      "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/wA=="
    cdp.allow_clipboard
    open_composer
    html = <<~HTML
        before 1<br>
        <img src="#{valid_png_data_uri}" alt="img1" width="100" height="100">
        <img src="#{valid_png_data_uri}" alt="img2">
        between<br>
        <img src="#{valid_jpeg_data_uri}">
        after 2
      HTML
    cdp.copy_paste(html, html: true)
    expect(rich).to have_css("img[alt='img1'][width='100'][height='100'][data-orig-src]")
    expect(rich).to have_css("img[alt='img2'][data-orig-src]")
    expect(rich).to have_css("img[alt='image'][data-orig-src]")
    expect(rich).to have_css("p", text: "before 1")
    expect(rich).to have_css("p", text: "between")
    expect(rich).to have_css("p", text: "after 2")
    expect(rich).to have_no_css("img[src^='data:']")
    # pasting a second time to make sure there's no cache pollution
    cdp.copy_paste("<img src='#{valid_png_data_uri}' alt='img1'>", html: true)
    expect(rich).to have_no_css("img[src^='data:']")
    expect(rich).to have_css("img[alt='img1'][data-orig-src]", count: 2)
  end

  context "when unauthorized to upload" do
    before { SiteSetting.authorized_extensions = "" }
    it "allows pasting text" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("Just some text")
      expect(rich).to have_css("p", text: "Just some text")
      composer.toggle_rich_editor
      expect(composer).to have_value("Just some text")
    end

    it "avoids triggering upload for paste" do
      open_composer
      cdp.allow_clipboard
      cdp.copy_test_image
      cdp.paste
      expect(rich).to have_no_css("img")
      composer.toggle_rich_editor
      expect(composer).to have_value("")
    end

    it "avoids triggering upload for base64" do
      valid_png_data_uri =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
      cdp.allow_clipboard
      open_composer
      html = <<~HTML
        <img src="#{valid_png_data_uri}" alt="img1" width="100" height="100">
      HTML
      cdp.copy_paste(html, html: true)
      expect(rich).to have_no_css("img")
      expect(rich).to have_text("image")
      composer.toggle_rich_editor
      expect(composer).to have_value("image")
    end

    it "replaces multiple base64 images with same data URI" do
      valid_png_data_uri =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
      cdp.allow_clipboard
      open_composer
      html = <<~HTML
        <p>before</p>
        <img src="#{valid_png_data_uri}" alt="img1">
        <p>middle</p>
        <img src="#{valid_png_data_uri}" alt="img2">
        <p>after</p>
      HTML
      cdp.copy_paste(html, html: true)
      expect(rich).to have_no_css("img")
      expect(rich).to have_text("before")
      expect(rich).to have_text("middle")
      expect(rich).to have_text("after")
      composer.toggle_rich_editor
      expect(composer).to have_value("before\n\nimage\n\nmiddle\n\nimage\n\nafter")
    end
  end

  it "merges text with link marks created from parsing" do
    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("This is a [link](https://example.com)")
    expect(rich).to have_css("a", text: "link")
    composer.type_content(:space)
    composer.type_content(:left)
    composer.type_content(:backspace)
    expect(rich).to have_css("a", text: "lin")
  end

  it "clears closed marks from stored marks when using markInputRule" do
    open_composer
    composer.type_content("[`something`](link) word")
    expect(rich).to have_css("a", text: "something")
    expect(rich).to have_css("a code", text: "something")
    expect(rich).to have_content("word")
    expect(rich).to have_no_css("code", text: "word")
  end

  it "parses html inline tags from pasted HTML" do
    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("<mark>mark</mark> my <ins>words</ins> <kbd>ctrl</kbd>", html: true)
    expect(rich).to have_css("mark", text: "mark")
    expect(rich).to have_css("ins", text: "words")
    expect(rich).to have_css("kbd", text: "ctrl")
    composer.toggle_rich_editor
    expect(composer).to have_value("<mark>mark</mark> my <ins>words</ins> <kbd>ctrl</kbd> ")
  end

  it "converts newlines to hard breaks when parsing `white-space: pre` HTML" do
    cdp.allow_clipboard
    open_composer
    cdp.copy_paste("<span style='white-space: pre;'>line1\nline2\nline3</pre>", html: true)
    expect(rich).to have_css("p", text: "line1")
    expect(rich).to have_css("p", text: "line2")
    expect(rich).to have_css("p", text: "line3")
    expect(rich).to have_css("br", count: 2)
    composer.toggle_rich_editor
    expect(composer).to have_value("line1\nline2\nline3")
  end

  context "when pasting tables" do
    it "fills incomplete rows" do
      cdp.allow_clipboard
      open_composer

      html = <<~HTML
        <table>
          <tbody>
            <tr><td>Title</td></tr>
            <tr><th>Column A</th><td>Column B</td></tr>
            <tr><th>Value 1</th><td>Value 2</td></tr>
            <tr><td colspan="2"></td></tr>
            <tr><th>Value 3</th><td>Value 4</td></tr>
          </tbody>
        </table>
      HTML

      cdp.copy_paste(html, html: true)

      composer.toggle_rich_editor

      markdown = <<~MARKDOWN
        | Title |  |
        |----|----|
        | Column A | Column B |
        | Value 1 | Value 2 |
        |  |  |
        | Value 3 | Value 4 |

      MARKDOWN

      expect(composer).to have_value(markdown)
    end

    it "normalizes column counts when header has fewer columns than body rows" do
      cdp.allow_clipboard
      open_composer

      html = <<~HTML
        <table>
          <tbody>
            <tr><th>Header1</th><th>Header2</th></tr>
            <tr><td>Cell1</td><td>Cell2</td><td>Cell3</td><td>Cell4</td></tr>
            <tr><td>Data1</td><td>Data2</td><td>Data3</td><td>Data4</td></tr>
          </tbody>
        </table>
      HTML

      cdp.copy_paste(html, html: true)

      composer.toggle_rich_editor

      markdown = <<~MARKDOWN
        | Header1 | Header2 |  |  |
        |----|----|----|----|
        | Cell1 | Cell2 | Cell3 | Cell4 |
        | Data1 | Data2 | Data3 | Data4 |

      MARKDOWN

      expect(composer).to have_value(markdown)
    end

    it "normalizes nested table column counts" do
      cdp.allow_clipboard
      open_composer

      html = <<~HTML
        <table>
          <tbody>
            <tr>
            <td>
              <table>
                <tbody>
                  <tr><td>CLOSED DOWNSTREAM</td></tr>
                  <tr><td colspan="2"></td></tr>
                  <tr><th>Alias:</th><td>None</td></tr>
                  <tr><th>Product:</th><td>name</td></tr>
                  <tr><th>Component:</th><td>general</td></tr>
                </tbody>
             </table>
            </td>
          <td></td>
          <td></td>
        </tr>
        </tbody>
        </table>
      HTML

      cdp.copy_paste(html, html: true)

      composer.toggle_rich_editor

      # The inner table header should be properly normalized
      markdown = <<~MARKDOWN
        |  |
        |----|


        | CLOSED DOWNSTREAM |  |
        |----|----|
        |  |  |
        | Alias: | None |
        | Product: | name |
        | Component: | general |


        |  |  |
        |----|----|

      MARKDOWN

      expect(composer).to have_value(markdown)
    end
  end
end
