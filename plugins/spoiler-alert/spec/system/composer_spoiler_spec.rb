# frozen_string_literal: true

describe "Composer - ProseMirror editor - Spoiler extension", type: :system do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end

  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  def click_spoiler_button
    find(".toolbar-menu__options-trigger").click
    find("[title='#{I18n.t("js.spoiler.title")}']").click
  end

  before { sign_in(current_user) }

  def open_composer
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus
  end

  it "creates inline spoiler when cursor is at end of line" do
    open_composer

    composer.type_content("This is a test ")
    click_spoiler_button

    expect(rich).to have_css("span.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("spoiler")

    expect(rich).to have_css("span.spoiled", text: "spoiler")

    composer.toggle_rich_editor

    expect(composer).to have_value("This is a test [spoiler]spoiler[/spoiler] ")
  end

  it "creates block spoiler when cursor is at start of line" do
    open_composer

    click_spoiler_button

    expect(rich).to have_css("div.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("spoiler")
    composer.toggle_rich_editor

    expect(composer).to have_value("[spoiler]\nspoiler\n\n[/spoiler]\n\n")
  end

  it "creates block spoiler with input rule when cursor is at start of line" do
    open_composer
    composer.type_content("[spoiler]")
    composer.type_content("inside")
    composer.toggle_rich_editor

    expect(composer).to have_value("[spoiler]\ninside\n\n[/spoiler]\n\n")
  end

  it "wraps selected text in inline spoiler when selection is within same paragraph" do
    open_composer

    composer.type_content("This is **secret** text here")
    find("strong", text: "secret").double_click
    click_spoiler_button

    expect(rich).to have_css("span.spoiled strong", text: "secret")
    expect(rich).to have_content("This is secret text here")

    composer.toggle_rich_editor
    expect(composer).to have_value("This is [spoiler]**secret**[/spoiler] text here")
  end

  it "wraps selected text in block spoiler when selection spans multiple paragraphs" do
    open_composer

    composer.type_content("First paragraph")
    composer.send_keys(:enter)
    composer.type_content("Second paragraph")
    composer.select_all
    click_spoiler_button

    expect(rich).to have_css("div.spoiled p", text: "First paragraph")
    expect(rich).to have_css("div.spoiled p", text: "Second paragraph")

    composer.toggle_rich_editor
    expect(composer).to have_value(
      "[spoiler]\nFirst paragraph\n\nSecond paragraph\n\n[/spoiler]\n\n",
    )
  end

  it "removes inline spoiler when cursor is inside inline spoiler" do
    open_composer

    composer.type_content("This is a test")
    click_spoiler_button

    expect(rich).to have_css("span.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("secret")
    composer.send_keys(:left, :left, :left)
    click_spoiler_button

    expect(rich).to have_no_css("span.spoiled")
    expect(rich).to have_content("This is a testsecret")
  end

  it "removes spoiler when cursor is inside block spoiler" do
    open_composer

    click_spoiler_button

    expect(rich).to have_css("div.spoiled")

    composer.type_content("secret content")

    click_spoiler_button

    expect(rich).to have_no_css("div.spoiled")
    expect(rich).to have_css("p", text: "secret content")
  end

  it "removes spoiler when text is selected within spoiler" do
    open_composer

    composer.type_content("Normal text")
    click_spoiler_button

    expect(rich).to have_css("span.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("hidden text")

    expect(rich).to have_css("span.spoiled", text: "hidden text")

    click_spoiler_button

    expect(rich).to have_no_css("span.spoiled")
    expect(rich).to have_content("Normal texthidden text")
  end

  it "handles multi-blocks spoiler full lift" do
    open_composer
    click_spoiler_button

    expect(rich).to have_css("div.spoiled")

    composer.type_content("First paragraph\nSecond paragraph")
    composer.send_keys(:up)
    click_spoiler_button

    expect(rich).to have_no_css("div.spoiled")
    expect(rich).to have_css("p", text: "First paragraph")
    expect(rich).to have_css("p", text: "Second paragraph")

    composer.toggle_rich_editor
    expect(composer).to have_value("First paragraph\n\nSecond paragraph")
  end

  it "breaks out of inline spoiler when pressing Enter" do
    open_composer

    composer.type_content("Test ")

    expect(rich).to have_css("p", text: "Test")

    click_spoiler_button

    expect(rich).to have_css("span.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("hello")
    composer.send_keys(:right)
    composer.type_content("X")

    expect(rich).to have_css("span.spoiled.spoiler-blurred", text: "hello")

    composer.send_keys(:left)
    composer.send_keys(:left)

    expect(rich).to have_css("span.spoiled:not(.spoiler-blurred)", text: "hello")

    # ENTER at the end of the node
    composer.send_keys(:enter)

    # Backspace, position cursor at hell|o, ENTER
    composer.send_keys(:backspace)
    composer.send_keys(:left)
    composer.send_keys(:left)
    sleep 0.01
    composer.send_keys(:enter)

    expect(rich).to have_css("p", text: "Test")
    expect(rich).to have_css("span.spoiled", text: "hell")
    expect(rich).to have_css("p:has(span.spoiled) + p", text: "o X")
  end

  it "keeps inline spoiler when pressing Enter at start of node" do
    open_composer

    composer.type_content(" ")
    click_spoiler_button

    expect(rich).to have_css("span.spoiled", text: I18n.t("js.composer.spoiler_text"))

    composer.type_content("hello")

    expect(rich).to have_css("span.spoiled", text: "hello")

    composer.send_keys(:control, :left)
    composer.send_keys(:backspace)
    sleep 0.01
    composer.send_keys(:enter)

    expect(rich).to have_css("p:not(:has(span.spoiled)) + p:has(span.spoiled)", text: "hello")
  end

  it "selects the resulting node after a select all and spoiler click" do
    open_composer

    composer.type_content("This is a test")
    composer.select_all
    click_spoiler_button

    expect(rich).to have_css("div.spoiled", text: "This is a test")

    composer.type_content("spoiled")

    composer.toggle_rich_editor
    expect(composer).to have_value("[spoiler]\nspoiled\n\n[/spoiler]\n\n")
  end

  it "can spoiler a block node selection" do
    open_composer

    composer.type_content("> Blockquote")

    find("blockquote").click(SystemHelpers::PLATFORM_KEY_MODIFIER)
    find("blockquote").click(SystemHelpers::PLATFORM_KEY_MODIFIER)

    click_spoiler_button

    expect(rich).to have_css("div.spoiled", text: "Blockquote")

    composer.toggle_rich_editor
    expect(composer).to have_value("[spoiler]\n> Blockquote\n\n[/spoiler]\n\n")
  end
end
