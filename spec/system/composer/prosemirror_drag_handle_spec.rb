# frozen_string_literal: true

RSpec.describe "Composer - ProseMirror - Block drag handle" do
  include_context "with prosemirror editor"

  it "lets the user reorder blocks by dragging their handle" do
    open_composer
    composer.type_content("First paragraph\n\nSecond paragraph\n\nThird paragraph")

    composer.drag_rich_editor_block(source: "Second paragraph", after: "Third paragraph") do
      expect(composer).to have_dragging_rich_editor_block
      expect(composer).to have_rich_editor_drop_indicator
    end

    expect(composer).to have_rich_editor_blocks(
      "First paragraph",
      "Third paragraph",
      "Second paragraph",
    )
  end

  it "lets the user reorder nested list items without flattening them" do
    open_composer
    composer.type_content("* Parent\nFirst nested")
    composer.send_keys(:tab)
    composer.type_content("\nSecond nested")

    expect(composer).to have_nested_list_items("First nested", "Second nested")

    composer.drag_rich_editor_block(source: "First nested", after: "Second nested")

    expect(composer).to have_nested_list_items("Second nested", "First nested")
  end
end
