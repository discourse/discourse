# frozen_string_literal: true

describe "Composer - ProseMirror - Toolbar" do
  include_context "with prosemirror editor"

  describe "toolbar state updates" do
    it "updates the toolbar state following the cursor position" do
      open_composer

      expect(
        browser_root.locator(".toolbar__button.bold.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.italic.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.heading.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.link.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.list.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.code.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".toolbar__button.blockquote.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      composer.type_content("> - [***many `styles`***](https://example.com)")
      begin
        browser_page.keyboard.press("ArrowLeft")
        browser_page.keyboard.press("ArrowLeft")
      end

      expect(
        browser_root.locator(".toolbar__button.bold.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".toolbar__button.italic.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".toolbar__button.link.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".toolbar__button.list.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".toolbar__button.code.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".toolbar__button.blockquote.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
    end
  end

  describe "trailing paragraph" do
    it "ensures there is always a trailing paragraph" do
      open_composer

      expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.have_count(1)
      composer.type_content("This is a test")

      expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.have_count(1)
      expect(
        rich
          .locator("p")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("This is a test")),
      ).to PlaywrightMatchers.have_count(1)

      browser_page.keyboard.press(
        [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Shift", "_"].join(
          "+",
        ),
      ) # Insert a horizontal rule
      expect(rich.locator("hr").filter(visible: true)).to PlaywrightMatchers.have_count(1)
      expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.have_count(2) # New paragraph inserted after the ruler
    end
  end

  describe "auto-linking/unlinking while typing" do
    it "auto-links non-protocol URLs and removes the link when no longer a URL" do
      open_composer

      composer.type_content("www.example.com and also mid-paragraph www.example2.com")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("www.example.com")],
        useInnerText: true,
      )
      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("www.example2.com")],
        useInnerText: true,
      )
      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.have_count(2)

      browser_page.keyboard.press("Backspace")
      browser_page.keyboard.press("Backspace")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.have_count(1)

      composer.type_content("om")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("www.example2.com")],
        useInnerText: true,
      )
    end

    it "auto-links protocol URLs" do
      open_composer

      composer.type_content("https://example.com")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )

      browser_page.keyboard.press("Backspace")
      browser_page.keyboard.press("Backspace")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.c")],
        useInnerText: true,
      )
    end

    it "doesn't auto-link immediately following a `" do
      open_composer

      composer.type_content("`https://example.com`")

      expect(rich.locator("code").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )
    end

    it "doesn't auto-link within code marks" do
      open_composer

      composer.type_content("`code mark`")
      browser_page.keyboard.press("ArrowLeft")

      composer.type_content(" https://example.com")

      expect(rich.locator("code").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("code mark https://example.com")],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )
    end

    it "doesn't continue a <https://url> markup='autolink'" do
      open_composer

      composer.type_content("<https://example.com>.de")

      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("https://example.com.de")],
        useInnerText: true,
      )

      composer.toggle_rich_editor

      expect(composer).to have_value("<https://example.com>.de")
    end
  end

  describe "emojis" do
    it "has the only-emoji class if 1-3 emojis are 'alone'" do
      open_composer

      composer.type_content("> :smile: ")

      expect(rich.locator(".only-emoji").filter(visible: true)).to PlaywrightMatchers.have_count(1)

      composer.type_content(":P ")

      expect(rich.locator(".only-emoji").filter(visible: true)).to PlaywrightMatchers.have_count(2)

      composer.type_content(":D ")

      expect(rich.locator(".only-emoji").filter(visible: true)).to PlaywrightMatchers.have_count(3)

      composer.type_content("Hey!")

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".only-emoji")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "preserves formatting marks when replacing text with emojis using :code: pattern" do
      open_composer

      composer.type_content("**bold :smile:**")

      expect(
        rich.locator("strong img.emoji").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(rich.locator("strong").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("bold")],
        useInnerText: true,
      )

      composer.toggle_rich_editor
      expect(composer).to have_value("**bold :smile:**")
    end

    it "preserves formatting marks when replacing text with emojis using text shortcuts" do
      open_composer

      composer.type_content("*italics :) *")

      expect(
        rich.locator("em img.emoji").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(rich.locator("em").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("italics")],
        useInnerText: true,
      )

      composer.toggle_rich_editor
      expect(composer).to have_value("*italics :slight_smile:* ")
    end

    it "preserves link marks when replacing text with emojis" do
      open_composer

      composer.type_content("[link text :heart:](https://example.com)")

      expect(
        rich.locator("a img.emoji").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("link text")],
        useInnerText: true,
      )

      composer.toggle_rich_editor
      expect(composer).to have_value("[link text :heart:](https://example.com)")
    end
  end

  describe "list toolbar" do
    it "shows the list dropdown on mobile", mobile: true do
      open_composer

      list_menu = composer.list_menu
      list_menu.expand

      expect(
        browser_root.locator("[data-name='list-bullet']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-name='list-ordered']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can apply a bullet list from the dropdown" do
      open_composer

      composer.type_content("A list item")

      list_menu = composer.list_menu
      list_menu.expand
      list_menu.option("[data-name='list-bullet']").click

      expect(rich.locator("ul li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("A list item")],
        useInnerText: true,
      )
    end

    it "can apply an ordered list from the dropdown" do
      open_composer

      composer.type_content("A list item")

      list_menu = composer.list_menu
      list_menu.expand
      list_menu.option("[data-name='list-ordered']").click

      expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("A list item")],
        useInnerText: true,
      )
    end

    it "splits multi-line plain text into bullet list items" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste("apple\nbanana\ncoconut")
      composer.select_all

      list_menu = composer.list_menu
      list_menu.expand
      list_menu.option("[data-name='list-bullet']").click

      expect(rich.locator("ul li").filter(visible: true)).to PlaywrightMatchers.have_count(3)
      expect(rich.locator("ul li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("apple")],
        useInnerText: true,
      )
      expect(rich.locator("ul li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("banana")],
        useInnerText: true,
      )
      expect(rich.locator("ul li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("coconut")],
        useInnerText: true,
      )
    end

    it "splits multi-line plain text into ordered list items" do
      cdp.allow_clipboard
      open_composer

      cdp.copy_paste("apple\nbanana\ncoconut")
      composer.select_all

      list_menu = composer.list_menu
      list_menu.expand
      list_menu.option("[data-name='list-ordered']").click

      expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.have_count(3)
      expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("apple")],
        useInnerText: true,
      )
      expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("banana")],
        useInnerText: true,
      )
      expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("coconut")],
        useInnerText: true,
      )
    end
  end

  describe "heading toolbar" do
    it "updates toolbar active state and icon based on current heading level" do
      open_composer

      composer.type_content("## This is a test\n#### And this is another test")
      expect(
        browser_root.locator(".toolbar__button.heading.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root
          .locator(".toolbar__button.heading")
          .filter(visible: true)
          .locator(".d-icon-discourse-h4")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_page.keyboard.press("ArrowUp")
      expect(
        browser_root.locator(".toolbar__button.heading.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root
          .locator(".toolbar__button.heading")
          .filter(visible: true)
          .locator(".d-icon-discourse-h2")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      composer.select_all
      expect(
        browser_root.locator(".toolbar__button.heading.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root
          .locator(".toolbar__button.heading")
          .filter(visible: true)
          .locator(".d-icon-discourse-text")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "puts a check next to current heading level in toolbar dropdown, or no check if multiple formats are selected" do
      open_composer

      composer.type_content("## This is a test\n#### And this is another test")

      heading_menu = composer.heading_menu
      heading_menu.expand
      expect(
        heading_menu
          .option("[data-name='heading-4']")
          .locator(".d-icon-check")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      heading_menu.collapse

      composer.select_range_rich_editor(0, 0)
      expect(
        browser_root
          .locator(".toolbar__button.heading")
          .filter(visible: true)
          .locator(".d-icon-discourse-h2")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      heading_menu.expand
      expect(
        heading_menu
          .option("[data-name='heading-2']")
          .locator(".d-icon-check")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      heading_menu.collapse

      composer.select_all
      expect(
        browser_root.locator(".toolbar__button.heading.--active").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      heading_menu.expand
      expect(
        heading_menu
          .option("[data-name='heading-2']")
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".d-icon-check")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        heading_menu
          .option("[data-name='heading-4']")
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".d-icon-check")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "can change heading level or reset to paragraph" do
      open_composer

      composer.type_content("This is a test")
      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click

      expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )

      heading_menu.expand
      heading_menu.option("[data-name='heading-3']").click
      expect(rich.locator("h3").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )

      heading_menu.expand
      heading_menu.option("[data-name='heading-paragraph']").click
      expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )
    end

    it "can insert a heading on an empty line" do
      open_composer

      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click

      composer.type_content("This is a test")
      expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )
    end

    it "lets the user apply and remove small text" do
      open_composer

      composer.type_content("This is a test")
      composer.select_all
      browser_page.keyboard.press(
        [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "Alt", "5"].join(
          "+",
        ),
      )

      expect(rich.locator("p small").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )

      rich.locator("small").filter(visible: true).click
      heading_menu = composer.heading_menu
      heading_menu.expand
      expect(
        heading_menu
          .option("[data-name='heading-small']")
          .locator(".d-icon-check")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        heading_menu
          .option("[data-name='heading-paragraph']")
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".d-icon-check")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      heading_menu.option("[data-name='heading-small']").click

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("small")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )
    end

    it "lets the user switch between a heading and small text" do
      open_composer

      composer.type_content("This is a test")
      composer.select_all

      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click
      expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )

      composer.select_all
      heading_menu.expand
      heading_menu.option("[data-name='heading-small']").click

      expect(rich.locator("p small").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("h2")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      composer.select_all
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click

      expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("This is a test")],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("small")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end
  end
end
