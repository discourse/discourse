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
      page.send_keys(:enter)

      expect(rich).to have_css("div.onebox-wrapper")
      rich.find("div.onebox-wrapper").click

      expect(onebox_toolbar).to have_toolbar
      expect(onebox_toolbar).to have_copy_button
      expect(onebox_toolbar).to have_remove_preview_button
      expect(onebox_toolbar).to have_visit_link
    end

    it "removes preview and converts to plain link" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      page.send_keys(:enter)

      expect(rich).to have_css("div.onebox-wrapper")
      rich.find("div.onebox-wrapper").click
      onebox_toolbar.click_remove_preview

      expect(rich).to have_no_css("div.onebox-wrapper")
      expect(rich).to have_css("a[href='https://example.com']", text: "https://example.com")

      composer.toggle_rich_editor
      expect(composer).to have_value("<https://example.com>")
    end

    it "does not re-onebox after removing preview" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      page.send_keys(:enter)

      expect(rich).to have_css("div.onebox-wrapper")
      rich.find("div.onebox-wrapper").click
      onebox_toolbar.click_remove_preview

      expect(rich).to have_no_css("div.onebox-wrapper")
      expect(rich).to have_css("a[href='https://example.com']")

      # Move cursor away and back — should not re-onebox
      composer.type_content(:enter)
      composer.type_content("some more text")
      expect(rich).to have_no_css("div.onebox-wrapper")
    end
  end

  context "with inline onebox" do
    it "shows toolbar when selecting an inline onebox" do
      cdp.allow_clipboard
      open_composer
      composer.type_content("Check ")
      cdp.copy_paste("https://example.com/x")
      composer.type_content(:space)

      expect(rich).to have_css("a.inline-onebox")
      rich.find("a.inline-onebox").click

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

      expect(rich).to have_css("a.inline-onebox", text: "Example Site")
      rich.find("a.inline-onebox").click
      onebox_toolbar.click_remove_preview

      expect(rich).to have_no_css("a.inline-onebox")
      expect(rich).to have_css("a[href='https://example.com/x']", text: "https://example.com/x")
    end
  end

  context "with show preview on link toolbar" do
    it "re-oneboxes a full onebox when clicking show preview" do
      cdp.allow_clipboard
      open_composer
      cdp.copy_paste("https://example.com")
      page.send_keys(:enter)

      expect(rich).to have_css("div.onebox-wrapper")
      rich.find("div.onebox-wrapper").click
      onebox_toolbar.click_remove_preview

      expect(rich).to have_no_css("div.onebox-wrapper")
      rich.find("a[href='https://example.com']").click

      expect(page).to have_css("button.composer-link-toolbar__show-preview")
      find("button.composer-link-toolbar__show-preview").click
      expect(rich).to have_css("div.onebox-wrapper")
    end

    it "re-oneboxes an inline onebox when clicking show preview" do
      cdp.allow_clipboard
      open_composer
      composer.type_content("Check ")
      cdp.copy_paste("https://example.com/x")
      composer.type_content(:space)

      expect(rich).to have_css("a.inline-onebox")
      rich.find("a.inline-onebox").click
      onebox_toolbar.click_remove_preview

      expect(rich).to have_no_css("a.inline-onebox")
      rich.find("a[href='https://example.com/x']").click

      expect(page).to have_css("button.composer-link-toolbar__show-preview")
      find("button.composer-link-toolbar__show-preview").click
      expect(rich).to have_css("a.inline-onebox")
    end
  end
end
