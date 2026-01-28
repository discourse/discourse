# frozen_string_literal: true

describe "Composer - ProseMirror - Toolbar", type: :system do
  include_context "with prosemirror editor"

  describe "toolbar state updates" do
    it "updates the toolbar state following the cursor position" do
      open_composer

      expect(page).to have_css(".toolbar__button.bold.--active", count: 0)
      expect(page).to have_css(".toolbar__button.italic.--active", count: 0)
      expect(page).to have_css(".toolbar__button.heading.--active", count: 0)
      expect(page).to have_css(".toolbar__button.link.--active", count: 0)
      expect(page).to have_css(".toolbar__button.list.--active", count: 0)
      expect(page).to have_css(".toolbar__button.code.--active", count: 0)
      expect(page).to have_css(".toolbar__button.blockquote.--active", count: 0)

      composer.type_content("> - [***many `styles`***](https://example.com)")
      composer.send_keys(:left, :left)

      expect(page).to have_css(".toolbar__button.bold.--active", count: 1)
      expect(page).to have_css(".toolbar__button.italic.--active", count: 1)
      expect(page).to have_css(".toolbar__button.link.--active", count: 1)
      expect(page).to have_css(".toolbar__button.list.--active", count: 1)
      expect(page).to have_css(".toolbar__button.code.--active", count: 1)
      expect(page).to have_css(".toolbar__button.blockquote.--active", count: 1)
    end
  end

  describe "trailing paragraph" do
    it "ensures there is always a trailing paragraph" do
      open_composer

      expect(rich).to have_css("p", count: 1)
      composer.type_content("This is a test")

      expect(rich).to have_css("p", count: 1)
      expect(rich).to have_css("p", text: "This is a test", count: 1)

      composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "_"]) # Insert a horizontal rule
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
      try_until_success(reason: "Toolbar state updates asynchronously after selection change") do
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-2']")).to have_css(".d-icon-check")
      end
      heading_menu.collapse

      composer.select_all
      try_until_success(reason: "Toolbar state updates asynchronously after selection change") do
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-2']")).to have_no_css(".d-icon-check")
        expect(heading_menu.option("[data-name='heading-4']")).to have_no_css(".d-icon-check")
      end
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
