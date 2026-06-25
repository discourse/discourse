# frozen_string_literal: true

# Real-browser coverage for the editable rich-inline INSPECTOR control. The
# canvas inline editor has its own coverage; this proves the other edit surface:
# selecting a block surfaces an editable ProseMirror editor in the inspector
# (headless / no-canvas editing), edits commit back to the block on blur, and a
# mark applied there round-trips (plain string upgrades to doc-JSON, rendering
# as <strong> on the canvas).
describe "Wireframe inspector rich-text control" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  RICH_EDITOR = ".wireframe-inspector-rich-text__editor .wf-inline-editor"

  before do
    SiteSetting.wireframe_enabled = true

    theme_dir = File.expand_path("../fixtures/themes/wireframe-inline-edit-test-theme", __dir__)
    theme = RemoteTheme.import_theme_from_directory(theme_dir)
    Theme.find(SiteSetting.default_theme_id).child_themes << theme

    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "mounts an editable rich-text editor in the inspector seeded with the value" do
    visit("/latest")
    editor.enter

    # One click selects the heading; the inspector then shows its fields,
    # including the editable rich-text control for the `text` (richInline) arg.
    find(".d-block-heading").click

    expect(page).to have_css(RICH_EDITOR, text: "Hello world")
  end

  it "commits an inspector edit back to the block on blur" do
    visit("/latest")
    editor.enter
    find(".d-block-heading").click

    rich = find(RICH_EDITOR)
    rich.click
    rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
    rich.send_keys("Changed in inspector")

    # Blur out of the control (the empty grid cell, not the heading, avoids
    # starting a canvas edit) — commit fires and the canvas heading updates.
    editor.empty_cell(column: 2, row: 1).click

    expect(page).to have_css(".d-block-heading", text: "Changed in inspector")
  end

  it "bolds a selection from the inspector and round-trips to a <strong> on the canvas" do
    visit("/latest")
    editor.enter
    find(".d-block-heading").click

    rich = find(RICH_EDITOR)
    rich.click
    rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
    find(".wireframe-inspector-rich-text__btn[aria-label='Bold']").click

    editor.empty_cell(column: 2, row: 1).click

    expect(page).to have_css(".d-block-heading strong", text: "Hello world")
  end
end
