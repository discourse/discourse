# frozen_string_literal: true

describe "Composer - ProseMirror - Keyboard shortcuts" do
  include_context "with prosemirror editor"

  fab!(:category_with_emoji) do
    Fabricate(:category, slug: "cat", emoji: "cat", style_type: "emoji")
  end

  it "supports Ctrl + B to create a bold text" do
    open_composer
    composer.type_content([SystemHelpers::PLATFORM_KEY_MODIFIER, "b"])
    composer.type_content("This is bold")

    expect(rich.locator("strong").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is bold")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + I to create an italic text" do
    open_composer
    composer.type_content([SystemHelpers::PLATFORM_KEY_MODIFIER, "i"])
    composer.type_content("This is italic")

    expect(rich.locator("em").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is italic")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + K to create a link" do
    hyperlink_modal = PageObjects::Modals::Base.new
    open_composer
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "k"].join("+"),
    )
    expect(hyperlink_modal).to be_open
    expect(hyperlink_modal.header).to contain_text(
      browser_text_pattern(I18n.t("js.composer.link_dialog_title")),
      useInnerText: true,
    )
    browser_page.keyboard.type("https://www.example.com")
    browser_page.keyboard.press("Tab")
    browser_page.keyboard.type("This is a link")
    browser_page.keyboard.press("Enter")

    expect(rich.locator("a").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is a link")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + Shift + 7 to create an ordered list" do
    open_composer
    composer.type_content("Item 1")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "7"].join(
        "+",
      ),
    )

    expect(rich.locator("ol li").filter(visible: true)).to contain_text(
      [browser_text_pattern("Item 1")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + Shift + 8 to create a bullet list" do
    open_composer
    composer.type_content("Item 1")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "8"].join(
        "+",
      ),
    )

    expect(rich.locator("ul li").filter(visible: true)).to contain_text(
      [browser_text_pattern("Item 1")],
      useInnerText: true,
    )
  end

  it "lets the user nest and lift list items with Tab" do
    open_composer
    composer.type_content("* First\nSecond")

    browser_page.keyboard.press("Tab")
    expect(composer).to have_nested_list_item("Second")

    browser_page.keyboard.press(%w[Shift Tab].join("+"))
    expect(composer).to have_top_level_list_item("Second")
  end

  it "supports Ctrl + Shift + 9 to create a blockquote" do
    open_composer
    composer.type_content("This is a blockquote")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "9"].join(
        "+",
      ),
    )

    expect(rich.locator("blockquote").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is a blockquote")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + Shift + 1-4 for headings, 0 for reset" do
    open_composer
    (1..4).each do |i|
      composer.type_content("\nHeading #{i}")
      browser_page.keyboard.press(
        [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Alt", i.to_s].join(
          "+",
        ),
      )

      expect(rich.locator("h#{i}").filter(visible: true)).to contain_text(
        [browser_text_pattern("Heading #{i}")],
        useInnerText: true,
      )
    end

    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Alt", "0"].join("+"),
    )
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("h4")
        .filter(visible: true),
    ).to have_count(0)
  end

  it "supports Ctrl + Z and Ctrl + Shift + Z to undo and redo" do
    open_composer
    cdp.copy_paste("This is a test")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "z"].join("+"),
    )

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("p")
        .filter(visible: true),
    ).not_to contain_text([browser_text_pattern("This is a test")], useInnerText: true)

    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "z"].join(
        "+",
      ),
    )

    expect(rich.locator("p").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is a test")],
      useInnerText: true,
    )
  end

  it "supports Ctrl + Shift + _ to create a horizontal rule" do
    open_composer
    composer.type_content("This is a test")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "_"].join(
        "+",
      ),
    )

    expect(rich.locator("hr").filter(visible: true)).not_to have_count(0)
  end

  it "creates hard break when pressing Enter after double space at end of line" do
    open_composer
    composer.type_content("Line with double space  ")
    browser_page.keyboard.press("Enter")
    composer.type_content("Next line")

    composer.toggle_rich_editor
    expect(composer).to RSpecPredicates.have_value("Line with double space\nNext line")
  end

  it "supports Backspace to reset a heading" do
    open_composer
    composer.type_content("# With text")

    expect(rich.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("With text")],
      useInnerText: true,
    )

    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    wait_for_timeout
    browser_page.keyboard.press("Backspace")

    expect(rich.locator("p").filter(visible: true)).to contain_text(
      [browser_text_pattern("With text")],
      useInnerText: true,
    )
  end

  it "supports Backspace to reset a code_block" do
    open_composer
    composer.type_content("```code block")
    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    wait_for_timeout
    browser_page.keyboard.press("Backspace")

    expect(rich.locator("p").filter(visible: true)).to contain_text(
      [browser_text_pattern("code block")],
      useInnerText: true,
    )
  end

  it "doesn't add a new list item when backspacing from below a list" do
    open_composer
    composer.type_content("1. Item 1\nItem 2")
    browser_page.keyboard.press("ArrowDown")
    composer.type_content("Item 3")
    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    browser_page.keyboard.press("Backspace")

    expect(rich.locator("ol li").filter(visible: true)).to contain_text(
      [browser_text_pattern("Item 1")],
      useInnerText: true,
    )
    expect(rich.locator("ol li").filter(visible: true)).to contain_text(
      [browser_text_pattern("Item 2Item 3")],
      useInnerText: true,
    )
  end

  it "supports hashtag decoration when pressing return" do
    open_composer

    composer.type_content("##{category_with_emoji.slug}")
    browser_page.keyboard.press("Space")
    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    wait_for_timeout
    browser_page.keyboard.press("Enter")

    expect(
      rich.locator("a.hashtag-cooked .emoji[alt='#{category_with_emoji.emoji}']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end

  it "supports hashtag decoration when backspacing to combine paragraphs" do
    open_composer

    composer.type_content("some text ")
    browser_page.keyboard.press("Enter")

    composer.type_content("##{category_with_emoji.slug}")
    browser_page.keyboard.press("Space")
    browser_page.keyboard.press((RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home"))
    wait_for_timeout
    browser_page.keyboard.press("Backspace")

    expect(
      rich.locator("a.hashtag-cooked .emoji[alt='#{category_with_emoji.emoji}']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end

  it "supports Ctrl + M to toggle between rich and markdown editors" do
    open_composer

    composer.type_content("> This is a test")

    expect(composer).to RSpecPredicates.have_value(nil)
    expect(rich.locator("blockquote").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is a test")],
      useInnerText: true,
    )

    browser_page.keyboard.press(%w[Control m].join("+"))

    expect(composer).to RSpecPredicates.have_value("> This is a test")
    expect(composer).to have_no_rich_editor

    browser_page.keyboard.press(%w[Control m].join("+"))

    expect(composer).to RSpecPredicates.have_value(nil)
    expect(rich.locator("blockquote").filter(visible: true)).to contain_text(
      [browser_text_pattern("This is a test")],
      useInnerText: true,
    )
  end

  it "adds a new paragraph when ENTER is pressed after an image" do
    open_composer
    composer.type_content("![image](https://example.com/image.png)")
    begin
      browser_page.keyboard.press("ArrowRight")
      browser_page.keyboard.press("Enter")
    end
    composer.type_content("This is a test")

    composer.toggle_rich_editor
    expect(composer).to RSpecPredicates.have_value(
      "\n![image](https://example.com/image.png)\n\nThis is a test",
    )
  end
end
