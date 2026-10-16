# frozen_string_literal: true

describe "Composer - ProseMirror - Onebox Toolbar" do
  include_context "with prosemirror editor"

  let(:onebox_toolbar) { PageObjects::Components::ComposerOneboxToolbar.new }

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

  before do
    stub_request(:head, %r{https://example\.com.*}).to_return(status: 200)
    stub_request(:get, %r{https://example\.com.*}).to_return(
      status: 200,
      body: body("Example Site"),
    )
  end

  context "with full onebox" do
    it "shows toolbar when selecting a full onebox" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      browser_page.keyboard.press("Enter")

      expect(rich.locator("div.onebox-wrapper").filter(visible: true)).not_to have_count(0)
      rich.locator("div.onebox-wrapper").filter(visible: true).click

      expect(onebox_toolbar).to have_toolbar
      expect(onebox_toolbar).to have_copy_button
      expect(onebox_toolbar).to have_remove_preview_button
      expect(onebox_toolbar).to have_visit_link
    end

    it "removes preview and converts to plain link" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      browser_page.keyboard.press("Enter")

      expect(rich.locator("div.onebox-wrapper").filter(visible: true)).not_to have_count(0)
      rich.locator("div.onebox-wrapper").filter(visible: true).click
      onebox_toolbar.click_remove_preview

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("div.onebox-wrapper")
          .filter(visible: true),
      ).to have_count(0)
      expect(rich.locator("a[href='https://example.com']").filter(visible: true)).to contain_text(
        [browser_text_pattern("https://example.com")],
        useInnerText: true,
      )

      composer.toggle_rich_editor
      expect(composer).to RSpecPredicates.have_value("<https://example.com>")
    end

    it "does not re-onebox after removing preview" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      browser_page.keyboard.press("Enter")

      expect(rich.locator("div.onebox-wrapper").filter(visible: true)).not_to have_count(0)
      rich.locator("div.onebox-wrapper").filter(visible: true).click
      onebox_toolbar.click_remove_preview

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("div.onebox-wrapper")
          .filter(visible: true),
      ).to have_count(0)
      expect(rich.locator("a[href='https://example.com']").filter(visible: true)).not_to have_count(
        0,
      )

      # Move cursor away and back — should not re-onebox
      composer.type_content(:enter)
      composer.type_content("some more text")
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("div.onebox-wrapper")
          .filter(visible: true),
      ).to have_count(0)
    end
  end

  context "with inline onebox" do
    it "shows toolbar when selecting an inline onebox" do
      cdp.allow_clipboard
      open_composer
      composer.type_content("Check ")
      cdp.copy_paste("https://example.com/x")
      composer.type_content(:space)

      expect(rich.locator("a.inline-onebox").filter(visible: true)).not_to have_count(0)
      rich.locator("a.inline-onebox").filter(visible: true).click

      expect(onebox_toolbar).to have_toolbar
      expect(onebox_toolbar).to have_copy_button
      expect(onebox_toolbar).to have_remove_preview_button
    end

    it "removes inline preview and converts to plain link" do
      cdp.allow_clipboard
      open_composer
      composer.type_content("Check ")
      cdp.copy_paste("https://example.com/x")
      composer.type_content(:space)

      expect(rich.locator("a.inline-onebox").filter(visible: true)).to contain_text(
        [browser_text_pattern("Example Site")],
        useInnerText: true,
      )
      rich.locator("a.inline-onebox").filter(visible: true).click
      onebox_toolbar.click_remove_preview

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.inline-onebox")
          .filter(visible: true),
      ).to have_count(0)
      expect(rich.locator("a[href='https://example.com/x']").filter(visible: true)).to contain_text(
        [browser_text_pattern("https://example.com/x")],
        useInnerText: true,
      )
    end
  end

  context "with show preview on link toolbar" do
    it "re-oneboxes a full onebox when clicking show preview" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      browser_page.keyboard.press("Enter")

      expect(rich.locator("div.onebox-wrapper").filter(visible: true)).not_to have_count(0)
      rich.locator("div.onebox-wrapper").filter(visible: true).click
      onebox_toolbar.click_remove_preview

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("div.onebox-wrapper")
          .filter(visible: true),
      ).to have_count(0)
      rich.locator("a[href='https://example.com']").filter(visible: true).click

      expect(
        browser_root.locator("button.composer-link-toolbar__show-preview").filter(visible: true),
      ).not_to have_count(0)
      browser_root.locator("button.composer-link-toolbar__show-preview").filter(visible: true).click
      expect(rich.locator("div.onebox-wrapper").filter(visible: true)).not_to have_count(0)
    end

    it "re-oneboxes an inline onebox when clicking show preview" do
      cdp.allow_clipboard
      open_composer
      composer.type_content("Check ")
      cdp.copy_paste("https://example.com/x")
      composer.type_content(:space)

      expect(rich.locator("a.inline-onebox").filter(visible: true)).not_to have_count(0)
      rich.locator("a.inline-onebox").filter(visible: true).click
      onebox_toolbar.click_remove_preview

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.inline-onebox")
          .filter(visible: true),
      ).to have_count(0)
      rich.locator("a[href='https://example.com/x']").filter(visible: true).click

      expect(
        browser_root.locator("button.composer-link-toolbar__show-preview").filter(visible: true),
      ).not_to have_count(0)
      browser_root.locator("button.composer-link-toolbar__show-preview").filter(visible: true).click
      expect(rich.locator("a.inline-onebox").filter(visible: true)).not_to have_count(0)
    end
  end
end
