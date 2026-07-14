# frozen_string_literal: true

# Real-browser (Playwright) coverage for the wireframe editor's drag-and-drop.
# This is the faithful end-to-end layer: it loads the live-rendered grid, opens
# the editor, and performs a genuine native HTML5 drag (via the shared
# `SystemHelpers#drag_and_drop`) — the only layer that would have caught the
# `.wf-layout--grid` → `.d-block-layout--grid` regression in a real browser. A
# broken render→editor class contract means the overlay never mounts, so the
# grid drop target never registers and every drag below silently does nothing.
#
# The drop lands at (or offset within) the target's box, so the precise "between
# A and B" seam isn't reachable here — that between-insert math is covered
# deterministically by the JS gesture test (`stack-drag-gesture-test.gjs`). This
# layer proves the coarser, higher-value fact: in a real browser the overlay
# mounts and a palette block actually lands in a grid cell.
describe "Wireframe editor drag and drop" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  before do
    SiteSetting.wireframe_enabled = true

    theme_dir = File.expand_path("../fixtures/themes/wireframe-grid-test-theme", __dir__)
    theme = RemoteTheme.import_theme_from_directory(theme_dir)
    Theme.find(SiteSetting.default_theme_id).child_themes << theme

    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "mounts the grid overlay when entering the editor (drop target registers)" do
    visit("/latest")
    editor.enter

    # The overlay's empty-cell placeholders only render once the grid
    # container is located via the editor↔render class contract. Their
    # presence proves the grid drop target registered — the exact behaviour
    # the class-rename regression silently broke.
    expect(editor).to have_empty_cells
  end

  it "drops a palette block onto an occupied cell, inserting it into the adjacent gap" do
    visit("/latest")
    editor.enter

    # Seed grid: A @ col 1, B @ col 2. Dropping a fresh block on the trailing
    # (insert-after) edge of the occupied cell B inserts it next to B rather than
    # replacing it. The point isn't the exact target cell (that math is covered
    # by the JS gesture test, and the grid renders as a collapsed single-column
    # stack here anyway) — it's that a drop onto an occupied region still inserts
    # a real block instead of vanishing (the regression's symptom), and A and B
    # keep their places.
    editor.drag_palette_block(
      "heading",
      onto: editor.block_selector("wf-grid-cell-b"),
      at: :trailing,
    )

    expect(editor).to have_block_in_grid("d-block-heading")
    expect(editor).to have_block_in_cell("wf-grid-cell-a", column: 1, row: 1)
    expect(editor).to have_block_in_cell("wf-grid-cell-b", column: 2, row: 1)
  end

  it "drops a palette block into an empty grid cell" do
    visit("/latest")
    editor.enter

    editor.drag_palette_block("heading", onto: editor.empty_cell_selector(column: 3, row: 1))

    expect(editor).to have_block_in_cell("d-block-heading", column: 3, row: 1)
  end
end
