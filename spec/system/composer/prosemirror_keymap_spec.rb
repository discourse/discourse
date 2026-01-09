# frozen_string_literal: true

describe "Composer - ProseMirror - Keyboard shortcuts", type: :system do
  include_context "with prosemirror editor"

  it "supports Ctrl + B to create a bold text" do
    open_composer
    composer.type_content([SystemHelpers::PLATFORM_KEY_MODIFIER, "b"])
    composer.type_content("This is bold")

    expect(rich).to have_css("strong", text: "This is bold")
  end

  it "supports Ctrl + I to create an italic text" do
    open_composer
    composer.type_content([SystemHelpers::PLATFORM_KEY_MODIFIER, "i"])
    composer.type_content("This is italic")

    expect(rich).to have_css("em", text: "This is italic")
  end

  it "supports Ctrl + K to create a link" do
    hyperlink_modal = PageObjects::Modals::Base.new
    open_composer
    page.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "k"])
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
    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "7"])

    expect(rich).to have_css("ol li", text: "Item 1")
  end

  it "supports Ctrl + Shift + 8 to create a bullet list" do
    open_composer
    composer.type_content("Item 1")
    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "8"])

    expect(rich).to have_css("ul li", text: "Item 1")
  end

  it "supports Ctrl + Shift + 9 to create a blockquote" do
    open_composer
    composer.type_content("This is a blockquote")
    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "9"])

    expect(rich).to have_css("blockquote", text: "This is a blockquote")
  end

  it "supports Ctrl + Shift + 1-4 for headings, 0 for reset" do
    open_composer
    (1..4).each do |i|
      composer.type_content("\nHeading #{i}")
      composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :alt, i.to_s])

      expect(rich).to have_css("h#{i}", text: "Heading #{i}")
    end

    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :alt, "0"])
    expect(rich).not_to have_css("h4")
  end

  it "supports Ctrl + Z and Ctrl + Shift + Z to undo and redo" do
    open_composer
    cdp.copy_paste("This is a test")
    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "z"])

    expect(rich).not_to have_css("p", text: "This is a test")

    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "z"])

    expect(rich).to have_css("p", text: "This is a test")
  end

  it "supports Ctrl + Shift + _ to create a horizontal rule" do
    open_composer
    composer.type_content("This is a test")
    composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "_"])

    expect(rich).to have_css("hr")
  end

  it "creates hard break when pressing Enter after double space at end of line" do
    open_composer
    composer.type_content("Line with double space  ")
    composer.send_keys(:enter)
    composer.type_content("Next line")

    composer.toggle_rich_editor
    expect(composer).to have_value("Line with double space\nNext line")
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

  it "supports hashtag decoration when pressing return" do
    open_composer

    composer.type_content("##{category_with_emoji.slug}")
    composer.send_keys(:space)
    composer.send_keys(:home)
    wait_for_timeout
    composer.send_keys(:enter)

    expect(rich).to have_css("a.hashtag-cooked .emoji[alt='#{category_with_emoji.emoji}']")
  end

  it "supports hashtag decoration when backspacing to combine paragraphs" do
    open_composer

    composer.type_content("some text ")
    composer.send_keys(:enter)

    composer.type_content("##{category_with_emoji.slug}")
    composer.send_keys(:space)
    composer.send_keys(:home)
    wait_for_timeout
    composer.send_keys(:backspace)

    expect(rich).to have_css("a.hashtag-cooked .emoji[alt='#{category_with_emoji.emoji}']")
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

  it "adds a new paragraph when ENTER is pressed after an image" do
    open_composer
    composer.type_content("![image](https://example.com/image.png)")
    composer.send_keys(:right, :enter)
    composer.type_content("This is a test")

    composer.toggle_rich_editor
    expect(composer).to have_value("\n![image](https://example.com/image.png)\n\nThis is a test")
  end
end
