# frozen_string_literal: true

describe "Composer - ProseMirror - Toolbar" do
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
    it "lets the user edit independently linked text", aggregate_failures: true do
      open_composer

      aggregate_failures(
        "auto-links non-protocol URLs and removes the link when no longer a URL",
      ) do
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

      reset_composer

      aggregate_failures("auto-links protocol URLs") do
        composer.type_content("https://example.com")

        expect(rich).to have_css("a", text: "https://example.com")

        composer.send_keys(:backspace)
        composer.send_keys(:backspace)

        expect(rich).to have_css("a", text: "https://example.c")
      end

      reset_composer

      aggregate_failures("doesn't auto-link immediately following a `") do
        composer.type_content("`https://example.com`")

        expect(rich).to have_css("code", text: "https://example.com")
        expect(rich).to have_no_css("a", text: "https://example.com")
      end

      reset_composer

      aggregate_failures("doesn't auto-link within code marks") do
        composer.type_content("`code mark`")
        composer.send_keys(:left)

        composer.type_content(" https://example.com")

        expect(rich).to have_css("code", text: "code mark https://example.com")
        expect(rich).to have_no_css("a", text: "https://example.com")
      end

      reset_composer

      aggregate_failures("doesn't continue a <https://url> markup='autolink'") do
        composer.type_content("<https://example.com>.de")

        expect(rich).to have_css("a", text: "https://example.com")
        expect(rich).to have_no_css("a", text: "https://example.com.de")

        composer.toggle_rich_editor

        expect(composer).to have_value("<https://example.com>.de")
      end
    end
  end

  describe "emojis" do
    it "lets the user format independent emoji documents", aggregate_failures: true do
      open_composer

      aggregate_failures("has the only-emoji class if 1-3 emojis are 'alone'") do
        composer.type_content("> :smile: ")

        expect(rich).to have_css(".only-emoji", count: 1)

        composer.type_content(":P ")

        expect(rich).to have_css(".only-emoji", count: 2)

        composer.type_content(":D ")

        expect(rich).to have_css(".only-emoji", count: 3)

        composer.type_content("Hey!")

        expect(rich).to have_no_css(".only-emoji")
      end

      reset_composer

      aggregate_failures(
        "preserves formatting marks when replacing text with emojis using :code: pattern",
      ) do
        composer.type_content("**bold :smile:**")

        expect(rich).to have_css("strong img.emoji")
        expect(rich).to have_css("strong", text: "bold")

        composer.toggle_rich_editor
        expect(composer).to have_value("**bold :smile:**")
      end

      reset_composer

      aggregate_failures(
        "preserves formatting marks when replacing text with emojis using text shortcuts",
      ) do
        composer.type_content("*italics :) *")

        expect(rich).to have_css("em img.emoji")
        expect(rich).to have_css("em", text: "italics")

        composer.toggle_rich_editor
        expect(composer).to have_value("*italics :slight_smile:* ")
      end

      reset_composer

      aggregate_failures("preserves link marks when replacing text with emojis") do
        composer.type_content("[link text :heart:](https://example.com)")

        expect(rich).to have_css("a img.emoji")
        expect(rich).to have_css("a", text: "link text")

        composer.toggle_rich_editor
        expect(composer).to have_value("[link text :heart:](https://example.com)")
      end
    end
  end

  describe "list toolbar" do
    it "shows the list dropdown on mobile", mobile: true do
      open_composer

      list_menu = composer.list_menu
      list_menu.expand

      expect(page).to have_css("[data-name='list-bullet']")
      expect(page).to have_css("[data-name='list-ordered']")
    end

    it "lets the user create independent lists", aggregate_failures: true do
      open_composer

      aggregate_failures("can apply a bullet list from the dropdown") do
        composer.type_content("A list item")

        list_menu = composer.list_menu
        list_menu.expand
        list_menu.option("[data-name='list-bullet']").click

        expect(rich).to have_css("ul li", text: "A list item")
      end

      reset_composer

      aggregate_failures("can apply an ordered list from the dropdown") do
        composer.type_content("A list item")

        list_menu = composer.list_menu
        list_menu.expand
        list_menu.option("[data-name='list-ordered']").click

        expect(rich).to have_css("ol li", text: "A list item")
      end

      reset_composer

      aggregate_failures("splits multi-line plain text into bullet list items") do
        cdp.allow_clipboard

        cdp.copy_paste("apple\nbanana\ncoconut")
        composer.select_all

        list_menu = composer.list_menu
        list_menu.expand
        list_menu.option("[data-name='list-bullet']").click

        expect(rich).to have_css("ul li", count: 3)
        expect(rich).to have_css("ul li", text: "apple")
        expect(rich).to have_css("ul li", text: "banana")
        expect(rich).to have_css("ul li", text: "coconut")
      end

      reset_composer

      aggregate_failures("splits multi-line plain text into ordered list items") do
        cdp.allow_clipboard

        cdp.copy_paste("apple\nbanana\ncoconut")
        composer.select_all

        list_menu = composer.list_menu
        list_menu.expand
        list_menu.option("[data-name='list-ordered']").click

        expect(rich).to have_css("ol li", count: 3)
        expect(rich).to have_css("ol li", text: "apple")
        expect(rich).to have_css("ol li", text: "banana")
        expect(rich).to have_css("ol li", text: "coconut")
      end
    end
  end

  describe "heading toolbar" do
    it "lets the user format independent headings", aggregate_failures: true do
      open_composer

      aggregate_failures("updates toolbar active state and icon based on current heading level") do
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

      reset_composer

      aggregate_failures(
        "puts a check next to current heading level in toolbar dropdown, or no check if multiple formats are selected",
      ) do
        composer.type_content("## This is a test\n#### And this is another test")

        heading_menu = composer.heading_menu
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-4']")).to have_css(".d-icon-check")
        heading_menu.collapse

        composer.select_range_rich_editor(0, 0)
        expect(find(".toolbar__button.heading")).to have_css(".d-icon-discourse-h2")
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-2']")).to have_css(".d-icon-check")
        heading_menu.collapse

        composer.select_all
        expect(page).to have_no_css(".toolbar__button.heading.--active")
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-2']")).to have_no_css(".d-icon-check")
        expect(heading_menu.option("[data-name='heading-4']")).to have_no_css(".d-icon-check")
      end

      reset_composer

      aggregate_failures("can change heading level or reset to paragraph") do
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

      reset_composer

      aggregate_failures("can insert a heading on an empty line") do
        heading_menu = composer.heading_menu
        heading_menu.expand
        heading_menu.option("[data-name='heading-2']").click

        composer.type_content("This is a test")
        expect(rich).to have_css("h2", text: "This is a test")
      end

      reset_composer

      aggregate_failures("lets the user apply and remove small text") do
        composer.type_content("This is a test")
        composer.select_all
        composer.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :alt, "5"])

        expect(rich).to have_css("p small", text: "This is a test")

        rich.find("small").click
        heading_menu = composer.heading_menu
        heading_menu.expand
        expect(heading_menu.option("[data-name='heading-small']")).to have_css(".d-icon-check")
        expect(heading_menu.option("[data-name='heading-paragraph']")).to have_no_css(
          ".d-icon-check",
        )
        heading_menu.option("[data-name='heading-small']").click

        expect(rich).to have_no_css("small")
        expect(rich).to have_css("p", text: "This is a test")
      end

      reset_composer

      aggregate_failures("lets the user switch between a heading and small text") do
        composer.type_content("This is a test")
        composer.select_all

        heading_menu = composer.heading_menu
        heading_menu.expand
        heading_menu.option("[data-name='heading-2']").click
        expect(rich).to have_css("h2", text: "This is a test")

        composer.select_all
        heading_menu.expand
        heading_menu.option("[data-name='heading-small']").click

        expect(rich).to have_css("p small", text: "This is a test")
        expect(rich).to have_no_css("h2")

        composer.select_all
        heading_menu.expand
        heading_menu.option("[data-name='heading-2']").click

        expect(rich).to have_css("h2", text: "This is a test")
        expect(rich).to have_no_css("small")
      end
    end
  end
end
