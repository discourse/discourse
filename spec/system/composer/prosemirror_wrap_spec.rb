# frozen_string_literal: true

describe "Composer - ProseMirror - Inline and Block Wrap", type: :system do
  include_context "with prosemirror editor"

  it "supports [wrap] to create a wrap block" do
    open_composer
    composer.type_content("[wrap]")

    expect(rich).to have_css(".composer-wrap-node")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap]\n\n[/wrap]\n\n")
  end

  it "supports [wrap=name] to create a named wrap block" do
    open_composer
    composer.type_content("[wrap=example]")

    expect(rich).to have_css(".composer-wrap-node")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap=example]\n\n[/wrap]\n\n")
  end

  it "supports [wrap class=foo] to create a wrap block with attributes" do
    open_composer
    composer.type_content("[wrap class=highlight]")

    expect(rich).to have_css(".composer-wrap-node")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap class=highlight]\n\n[/wrap]\n\n")
  end

  it "creates inline wrap when not at start of line" do
    open_composer
    composer.type_content("Text before [wrap=inline]")

    expect(rich).to have_css(".composer-wrap-node")
    expect(rich).to have_content("Text before")
    expect(rich).to have_content("Wrap content")

    composer.toggle_rich_editor

    expect(composer).to have_value("Text before [wrap=inline]Wrap content[/wrap] ")
  end

  it "opens edit modal when clicking wrap indicator" do
    open_composer
    composer.type_content("[wrap=outer]")

    expect(rich).to have_css(".composer-wrap-node")

    rich.find(".d-wrap-indicator").click

    expect(page).to have_css(".wrap-attributes-modal")
    expect(page).to have_field("name", with: "outer") # Should show existing wrap name

    page.fill_in("name", with: "updated")

    page.find("button", text: "Add attribute").click

    within(".wrap-modal__attribute-row") do
      page.fill_in("Key", with: "class")
      page.fill_in("Value", with: "highlight")
    end

    page.find("button", text: "Apply").click

    expect(rich).to have_css(".composer-wrap-node", count: 1)

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap=updated class=highlight]\n\n[/wrap]\n\n")
  end

  it "opens edit modal from toolbar when cursor is inside existing wrap" do
    open_composer
    composer.type_content("[wrap=example class=test]")

    expect(rich).to have_css(".composer-wrap-node")

    rich.find(".composer-wrap-node").click

    find("#reply-control .d-editor-button-bar .toolbar__button.options").click

    find("[data-name='toggle-wrap']").click

    expect(page).to have_css(".wrap-attributes-modal")
    expect(page).to have_field("name", with: "example") # Should show existing wrap name
    expect(page).to have_field("Key", with: "class") # Should show existing class attribute
    expect(page).to have_field("Value", with: "test")

    page.fill_in("name", with: "updated")
    page.fill_in("Value", with: "highlight")
    page.find("button", text: "Apply").click

    expect(rich).to have_css(".composer-wrap-node", count: 1)

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap=updated class=highlight]\n\n[/wrap]\n\n")
  end
end
