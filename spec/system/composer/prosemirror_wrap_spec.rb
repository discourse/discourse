# frozen_string_literal: true

describe "Composer - ProseMirror - Inline and Block Wrap", type: :system do
  include_context "with prosemirror editor"

  it "supports [wrap] to create a wrap block" do
    open_composer
    composer.type_content("[wrap]")

    expect(rich).to have_css(".composer-wrap-node")
    expect(rich).to have_content("Wrap content")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap]\nWrap content\n\n[/wrap]\n\n")
  end

  it "supports [wrap=name] to create a named wrap block" do
    open_composer
    composer.type_content("[wrap=example]")

    expect(rich).to have_css(".composer-wrap-node")
    expect(rich).to have_content("Wrap content")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap=example]\nWrap content\n\n[/wrap]\n\n")
  end

  it "supports [wrap class=foo] to create a wrap block with attributes" do
    open_composer
    composer.type_content("[wrap class=highlight]")

    expect(rich).to have_css(".composer-wrap-node")

    composer.toggle_rich_editor

    expect(composer).to have_value("[wrap class=highlight]\nWrap content\n\n[/wrap]\n\n")
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
end
