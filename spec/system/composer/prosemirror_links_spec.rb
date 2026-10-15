# frozen_string_literal: true

describe "Composer - ProseMirror - Links" do
  include_context "with prosemirror editor"

  let(:upsert_hyperlink_modal) { PageObjects::Modals::UpsertHyperlink.new }

  it "shows link toolbar when cursor is on a link" do
    open_composer
    composer.type_content("[Example](https://example.com)")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("button.composer-link-toolbar__edit").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("button.composer-link-toolbar__copy").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("a.composer-link-toolbar__visit").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("example.com")], useInnerText: true)
  end

  it "allows editing a link via toolbar" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("[Example](https://example.com)")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    # Use Tab to navigate to the toolbar and Enter to activate edit
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    begin
      browser_page.keyboard.press("Tab")
      browser_page.keyboard.press("Enter")
    end
    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal.link_text_value).to eq("Example")
    expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")
    upsert_hyperlink_modal.fill_in_link_text("Updated Example")
    upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com")
    upsert_hyperlink_modal.send_enter_link_text
    expect(
      rich.locator("a[href='https://updated-example.com']").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Updated Example")],
      useInnerText: true,
    )
    composer.toggle_rich_editor
    expect(composer).to have_value("[Updated Example](https://updated-example.com)")
  end

  it "escapes URL when editing link via modal" do
    cdp.allow_clipboard
    open_composer
    composer.type_content("[Example](https://example.com)")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    # Use Tab to navigate to the toolbar and Enter to activate edit
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    begin
      browser_page.keyboard.press("Tab")
      browser_page.keyboard.press("Enter")
    end
    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal.link_text_value).to eq("Example")
    expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")
    upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com?query=with space")
    upsert_hyperlink_modal.click_primary_button
    expect(
      rich.locator("a[href='https://updated-example.com/?query=with%20space']").filter(
        visible: true,
      ),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Example")], useInnerText: true)
  end

  it "preserves existing percent escapes when inserting a link" do
    open_composer
    composer.click_toolbar_button("link")
    expect(upsert_hyperlink_modal).to be_open
    upsert_hyperlink_modal.fill_in_link_text("Encoded URL")
    upsert_hyperlink_modal.fill_in_link_url("https://example.com/%20test")
    upsert_hyperlink_modal.click_primary_button
    expect(
      rich.locator("a[href='https://example.com/%20test']").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Encoded URL")], useInnerText: true)
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
    expect(
      rich.locator("a[href='https://example.com/100%25/working%201']").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("Encoded URL")], useInnerText: true)
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    browser_root.locator("button.composer-link-toolbar__edit").filter(visible: true).click
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
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    browser_root.locator("button.composer-link-toolbar__copy").filter(visible: true).click
    expect(browser_content).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("js.composer.link_toolbar.link_copied")),
      useInnerText: true,
    )
  end

  it "allows unlinking a link via toolbar when markup is not auto or linkify" do
    open_composer
    composer.type_content("[Manual Link](https://example.com)")
    browser_root.locator("button.composer-link-toolbar__unlink").filter(visible: true).click
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("a")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(rich).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Manual Link"),
      useInnerText: true,
    )
    composer.toggle_rich_editor
    expect(composer).to have_value("Manual Link")
  end

  it "doesn't show unlink button for auto-detected links" do
    open_composer
    composer.type_content("<https://example.com>")
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("button.composer-link-toolbar__unlink").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("a.composer-link-toolbar__visit").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("")], useInnerText: true)
  end

  it "doesn't show unlink button for auto-linkified URLs" do
    open_composer
    composer.type_content("https://example.com")
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("button.composer-link-toolbar__unlink").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("a.composer-link-toolbar__visit").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("")], useInnerText: true)
  end

  it "shows visit button for valid URLs" do
    open_composer
    composer.type_content("[Example](https://example.com)")
    expect(
      browser_root.locator("a.composer-link-toolbar__visit[href='https://example.com']").filter(
        visible: true,
      ),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("example.com")], useInnerText: true)
  end

  it "strips base URL from internal links in toolbar display" do
    open_composer
    internal_link = "#{Discourse.base_url}/t/some-topic/123"
    composer.type_content("[Internal Link](#{internal_link})")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("a.composer-link-toolbar__visit[href='#{internal_link}']").filter(
        visible: true,
      ),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("/t/some-topic/123")],
      useInnerText: true,
    )
  end

  it "doesn't show visit button for invalid URLs" do
    open_composer
    composer.type_content("[Example](not-a-url)")
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("a.composer-link-toolbar__visit").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".composer-link-toolbar__divider").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "closes toolbar when cursor moves outside link" do
    open_composer
    composer.type_content("Text before [Example](https://example.com),")
    browser_page.keyboard.press("ArrowLeft")
    wait_for do
      PlaywrightMatchers.have_count(0).does_not_match?(
        browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
      )
    end
    expect(
      browser_root.locator("a.composer-link-toolbar__visit").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("example.com")], useInnerText: true)
    browser_page.keyboard.press("ArrowRight")
    wait_for do
      PlaywrightMatchers.have_count(0).matches?(
        browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
      )
    end
  end

  it "preserves emojis when editing a link via toolbar" do
    open_composer
    composer.type_content("[Party :tada: Time](https://example.com)")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    # Use Tab to navigate to the toolbar and Enter to activate edit
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    begin
      browser_page.keyboard.press("Tab")
      browser_page.keyboard.press("Enter")
    end
    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal.link_text_value).to eq("Party :tada: Time")
    expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")
    upsert_hyperlink_modal.fill_in_link_text("Updated :tada: Party")
    upsert_hyperlink_modal.fill_in_link_url("https://updated-party.com")
    upsert_hyperlink_modal.click_primary_button
    expect(
      rich.locator("a[href='https://updated-party.com']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      rich.locator("a img[title=':tada:'], a img[alt=':tada:']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    composer.toggle_rich_editor
    expect(composer).to have_value("[Updated :tada: Party](https://updated-party.com)")
  end

  it "preserves bold and italic formatting when editing a link via toolbar" do
    open_composer
    composer.type_content("[**Bold** and *italic* text](https://example.com)")
    begin
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
      browser_page.keyboard.press("ArrowLeft")
    end
    # Use Tab to navigate to the toolbar and Enter to activate edit
    expect(
      browser_root.locator("[data-identifier='composer-link-toolbar']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    begin
      browser_page.keyboard.press("Tab")
      browser_page.keyboard.press("Enter")
    end
    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal.link_text_value).to eq("**Bold** and *italic* text")
    expect(upsert_hyperlink_modal.link_url_value).to eq("https://example.com")
    upsert_hyperlink_modal.fill_in_link_text("Updated **bold** and *italic* content")
    upsert_hyperlink_modal.fill_in_link_url("https://updated-example.com")
    upsert_hyperlink_modal.click_primary_button
    expect(
      rich.locator("a[href='https://updated-example.com']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(rich.locator("strong a").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("bold")],
      useInnerText: true,
    )
    expect(rich.locator("em a").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("italic")],
      useInnerText: true,
    )
    composer.toggle_rich_editor
    expect(composer).to have_value(
      "[Updated **bold** and *italic* content](https://updated-example.com)",
    )
  end

  context "when inserting a link over an existing selection" do
    it "only shows the URL field in the modal" do
      open_composer
      composer.type_content("some text")
      composer.select_all
      composer.click_toolbar_button("link")

      expect(upsert_hyperlink_modal).to be_open
      expect(upsert_hyperlink_modal).to have_no_link_text_field
    end

    it "wraps the selection with the link while preserving inline formatting" do
      open_composer
      composer.type_content("Example")
      composer.select_all
      composer.click_toolbar_button("bold")
      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click
      expect(rich.locator("h2 strong").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Example")],
        useInnerText: true,
      )

      composer.select_all
      composer.click_toolbar_button("link")
      upsert_hyperlink_modal.fill_in_link_url("https://example.com")
      upsert_hyperlink_modal.click_primary_button

      expect(
        rich.locator("h2 strong a[href='https://example.com']").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("Example")], useInnerText: true)
      composer.toggle_rich_editor
      expect(composer).to have_value("## **[Example](https://example.com)**")
    end

    it "does not leak heading markdown into the resulting link" do
      open_composer
      composer.type_content("Example")
      composer.select_all
      heading_menu = composer.heading_menu
      heading_menu.expand
      heading_menu.option("[data-name='heading-2']").click
      expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Example")],
        useInnerText: true,
      )

      composer.select_all
      composer.click_toolbar_button("link")
      upsert_hyperlink_modal.fill_in_link_url("https://example.com")
      upsert_hyperlink_modal.click_primary_button

      expect(
        rich.locator("h2 a[href='https://example.com']").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("Example")], useInnerText: true)
      composer.toggle_rich_editor
      expect(composer).to have_value("## [Example](https://example.com)")
    end
  end

  context "in markdown mode, when inserting a link over an existing selection" do
    it "only shows the URL field and wraps the selection as-is" do
      open_composer
      composer.toggle_rich_editor
      composer.type_content("`code word`")
      composer.select_all
      composer.click_toolbar_button("link")

      expect(upsert_hyperlink_modal).to be_open
      expect(upsert_hyperlink_modal).to have_no_link_text_field
      upsert_hyperlink_modal.fill_in_link_url("https://example.com")
      upsert_hyperlink_modal.click_primary_button

      expect(composer).to have_value("[`code word`](https://example.com)")
    end
  end

  it "shows both fields when inserting a link without a selection" do
    open_composer
    composer.click_toolbar_button("link")

    expect(upsert_hyperlink_modal).to be_open
    expect(upsert_hyperlink_modal).to have_link_text_field
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
      expect(rich).to PlaywrightMatchers.contain_text(
        browser_text_pattern("Modified"),
        useInnerText: true,
      )
    end
  end
end
