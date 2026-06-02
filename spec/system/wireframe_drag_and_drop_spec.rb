# frozen_string_literal: true

# Real-browser (Playwright) coverage for the wireframe editor's drag-and-drop.
# This is the faithful end-to-end layer: it loads the live-rendered grid, opens
# the editor, and performs an actual pointer drag — the only layer that would
# have caught the `.wf-layout--grid` → `.d-block-layout--grid` regression in a
# real browser (a broken selector means the overlay never mounts, so the drop
# target never registers and every assertion below fails).
#
# PENDING: authored from core's `spec/system/blocks_spec.rb` + the editor's
# real DOM contracts, but NOT yet run green — the worktree this was developed
# in could not boot a test server (see the handoff notes). Un-skip and verify
# in a working dev/CI environment; the theme-fixture wiring (how the editor
# binds to the seeded grid layout) may need a small adjustment once it runs.
describe "Wireframe editor drag and drop" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  before do
    SiteSetting.wireframe_enabled = true

    theme_dir = Rails.root.join("spec/fixtures/themes/wireframe-grid-test-theme")
    theme = RemoteTheme.import_theme_from_directory(theme_dir.to_s)
    Theme.find(SiteSetting.default_theme_id).child_themes << theme

    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "mounts the grid overlay when entering the editor (drop target registers)" do
    skip("Pending verification in a working dev/CI env — see file header")

    visit("/latest")
    editor.enter

    # The overlay's empty-cell placeholders only render once the grid
    # container is located via the editor↔render class contract. Their
    # presence proves the grid drop target registered — the exact behaviour
    # the class-rename regression silently broke.
    expect(editor).to have_empty_cells
  end

  it "drops a palette block into the gap between two occupied cells" do
    skip("Pending verification in a working dev/CI env — see file header")

    visit("/latest")
    editor.enter

    # The regression scenario: a clear between-zone in the gap of an occupied
    # grid. Drag a fresh block from the palette onto the A|B seam; it should
    # land between them (cell B and the empty cell shift right).
    editor.palette_entry("heading").drag_to(editor.block("wf-grid-cell-b"), delay: 0.4)

    expect(editor).to have_block_in_cell("d-block-heading", column: 2, row: 1)
    expect(editor).to have_block_in_cell("wf-grid-cell-b", column: 3, row: 1)
  end

  it "drops a palette block into an empty grid cell" do
    skip("Pending verification in a working dev/CI env — see file header")

    visit("/latest")
    editor.enter

    editor.palette_entry("heading").drag_to(editor.empty_cell(column: 3, row: 1), delay: 0.4)

    expect(editor).to have_block_in_cell("d-block-heading", column: 3, row: 1)
  end
end
