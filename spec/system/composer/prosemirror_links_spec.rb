# frozen_string_literal: true

describe "Composer - ProseMirror - Links", type: :system do
  include_context "with prosemirror editor"

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

  it "preserves existing percent escapes when inserting a link" do
    open_composer
    composer.click_toolbar_button("link")
    expect(upsert_hyperlink_modal).to be_open
    upsert_hyperlink_modal.fill_in_link_text("Encoded URL")
    upsert_hyperlink_modal.fill_in_link_url("https://example.com/%20test")
    upsert_hyperlink_modal.click_primary_button
    expect(rich).to have_css("a[href='https://example.com/%20test']", text: "Encoded URL")
    composer.toggle_rich_editor
    expect(composer).to have_value("[Encoded URL](https://example.com/%20test)")
  end

  it "handles malformed links gracefully" do
    cdp.allow_clipboard
    open_composer
    composer.click_toolbar_button("link")
    expect(upsert_hyperlink_modal).to be_open
    upsert_hyperlink_modal.fill_in_link_text("Encoded URL")
    upsert_hyperlink_modal.fill_in_link_url("https://example.com/100%/working 1")
    upsert_hyperlink_modal.click_primary_button
    expect(rich).to have_css(
      "a[href='https://example.com/100%25/working%201']",
      text: "Encoded URL",
    )
    composer.send_keys(:left, :left, :left)
    find("button.composer-link-toolbar__edit").click
    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal.link_text_value).to eq("Encoded URL")
    # this ensures we keeps the corrected encoding and do not decode prior to edit
    # if we decode prior to edit user may end up being confused about why the url has spaces etc...
    expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com/100%25/working%201")
    upsert_hyperlink_modal.close
    composer.toggle_rich_editor
    expect(composer).to have_value("[Encoded URL](https://example.com/100%25/working%201)")
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
    wait_for { page.has_css?("[data-identifier='composer-link-toolbar']") }
    expect(page).to have_css("a.composer-link-toolbar__visit", text: "example.com")
    composer.send_keys(:right)
    wait_for { page.has_no_css?("[data-identifier='composer-link-toolbar']") }
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

  it "does not infinite loop on link rewrite" do
    with_logs do |logger|
      open_composer
      composer.type_content("[Example](https://example.com)")
      composer.type_content([SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
      composer.type_content("Modified")
      expect(logger.logs.map { |log| log[:message] }).not_to include(
        "Maximum call stack size exceeded",
      )
      expect(rich).to have_content("Modified")
    end
  end
end
