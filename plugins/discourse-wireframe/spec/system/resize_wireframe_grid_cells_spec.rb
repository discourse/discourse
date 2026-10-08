# frozen_string_literal: true

describe "Resize wireframe grid cells" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }
  let(:grid) { PageObjects::Components::WireframeGridResize.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.external_system_avatars_enabled = true
    SiteSetting.external_system_avatars_url =
      "/images/discourse-logo-sketch.png?v={username}&s={size}"
    theme =
      RemoteTheme.import_theme_from_directory(
        File.expand_path("../fixtures/themes/wireframe-grid-resize-test-theme", __dir__),
      )
    Theme.find(SiteSetting.default_theme_id).child_themes << theme
    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "lets an author span columns and rows by dragging a filled cell's edges and corner" do
    visit("/latest")
    editor.enter
    grid.select_filled_cell
    expect(grid).to have_positioned_filled_handles
    screenshot_marker(label: "wireframe-grid-resize-handles", only: :desktop)

    grid.resize_filled_cell("e", column: 3, row: 2)
    expect(grid).to have_filled_span(column: "2 / 4", row: "2")
    grid.resize_filled_cell("s", column: 2, row: 3)
    expect(grid).to have_filled_span(column: "2 / 4", row: "2 / 4")
    grid.resize_filled_cell("nw", column: 1, row: 1)
    expect(grid).to have_filled_span(column: "1 / 4", row: "1 / 4")
    screenshot_marker(label: "wireframe-grid-resize-span", only: :desktop)
    grid.resize_filled_cell("se", column: 2, row: 2)
    expect(grid).to have_filled_span(column: "1 / 3", row: "1 / 3")
  end

  it "lets an author merge empty cells across columns and rows with their handles" do
    visit("/latest")
    editor.enter
    grid.resize_empty_cell(column: 1, row: 1, direction: "e", to_column: 2, to_row: 1)
    expect(grid).to have_empty_span(column: "1 / 3", row: "1")
    grid.resize_empty_cell(column: 3, row: 1, direction: "s", to_column: 3, to_row: 2)
    expect(grid).to have_empty_span(column: "3", row: "1 / 3")
  end
end
