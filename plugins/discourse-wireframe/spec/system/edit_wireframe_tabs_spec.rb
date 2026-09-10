# frozen_string_literal: true

describe "Edit wireframe tabs" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:tabs_editor) { PageObjects::Components::WireframeTabsEditor.new }
  let(:panel_switcher) { PageObjects::Components::WireframePanelSwitcher.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.external_system_avatars_enabled = true
    SiteSetting.external_system_avatars_url =
      "/images/discourse-logo-sketch.png?v={username}&s={size}"
    theme =
      RemoteTheme.import_theme_from_directory(
        File.expand_path("../fixtures/themes/wireframe-tabs-test-theme", __dir__),
      )
    Theme.find(SiteSetting.default_theme_id).child_themes << theme
    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "switches, resizes and collapses activity panels beside the canvas" do
    visit "/latest"
    tabs_editor.enter
    panel_switcher.open_layers
    expect(panel_switcher).to have_layers_panel
    expect(panel_switcher).to have_aligned_panel
    screenshot_marker(label: "wireframe-activity-tabs", only: :desktop)

    panel_switcher.resize_to_minimum
    expect(panel_switcher).to have_minimum_width
    expect(panel_switcher).to have_aligned_panel
    panel_switcher.resize_to_maximum
    expect(panel_switcher).to have_maximum_width
    expect(panel_switcher).to have_aligned_panel

    panel_switcher.open_layers
    expect(panel_switcher).to have_collapsed_panel
    screenshot_marker(label: "wireframe-activity-tabs-collapsed", only: :desktop)
    panel_switcher.toggle_collapsed
    expect(panel_switcher).to have_layers_panel
    expect(panel_switcher).to have_aligned_panel
  end

  it "scrolls overflowing tabs without changing the selected panel" do
    visit "/latest"
    tabs_editor.enter
    expect(tabs_editor).to have_selected_panel
    expect(tabs_editor).to have_interactive_overflow
    tabs_editor.scroll_forward
    expect(tabs_editor).to have_scrolled_tabs
    expect(tabs_editor).to have_selected_panel
    screenshot_marker(label: "wireframe-dtabs-overflow", only: :desktop)
  end

  it "edits a tab label in place and reviews the change" do
    visit "/latest"
    tabs_editor.enter
    tabs_editor.rename_first_panel
    expect(tabs_editor).to have_renamed_panel
    tabs_editor.open_review
    expect(tabs_editor).to have_bounded_review
    screenshot_marker(label: "wireframe-dtabs-review-details", only: :desktop)
    tabs_editor.show_changes
    expect(tabs_editor).to have_bounded_review
    screenshot_marker(label: "wireframe-dtabs-review-changes", only: :desktop)
  end
end
