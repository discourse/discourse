# frozen_string_literal: true

describe "Edit wireframe images" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }
  let(:image_editor) { PageObjects::Components::WireframeImageEditor.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.external_system_avatars_enabled = true
    SiteSetting.external_system_avatars_url =
      "/images/discourse-logo-sketch.png?v={username}&s={size}"
    theme =
      RemoteTheme.import_theme_from_directory(
        File.expand_path("../fixtures/themes/wireframe-image-test-theme", __dir__),
      )
    Theme.find(SiteSetting.default_theme_id).child_themes << theme
    sign_in(admin)
  end

  after { Theme.clear_cache! }

  it "lets an author position a section image and cancel canvas adjustment" do
    visit("/latest")
    editor.enter
    frame_width, cell_width = image_editor.grid_frame_widths
    expect(frame_width).to eq(cell_width)
    image_editor.select_section
    expect(image_editor).to have_composition_controls
    image_editor.set_position(x: 25, y: 75)
    expect(image_editor).to have_position(x: 25, y: 75)
    screenshot_marker(label: "wireframe-image-controls", only: :desktop)

    image_editor.reposition
    expect(image_editor).to have_adjustment
    geometry = image_editor.adjustment_geometry
    expect(geometry["overlay"]["width"]).to be_within(1).of(geometry["frame"]["width"]),
    geometry.inspect
    expect(geometry["overlay"]["left"]).to be_within(1).of(geometry["frame"]["left"]),
    geometry.inspect
    expect(geometry["overlay"]["right"]).to be <= geometry["chrome"]["right"], geometry.inspect
    image_editor.nudge(:right)
    expect(image_editor).to have_position(x: 26, y: 75)
    screenshot_marker(label: "wireframe-image-reposition", only: :desktop)
    image_editor.cancel_adjustment
    expect(image_editor).to have_no_adjustment
    expect(image_editor).to have_position(x: 25, y: 75)

    image_editor.reposition
    image_editor.nudge(:left)
    image_editor.finish_adjustment
    expect(image_editor).to have_no_adjustment
    expect(image_editor).to have_position(x: 24, y: 75)

    image_editor.reposition
    drag_with_pointer(from: ".wireframe-image-reposition__surface", by: { x: 40 })
    expect(image_editor).to have_no_position(x: 24, y: 75)
    expect(image_editor).to have_selected_section
    image_editor.cancel_adjustment
    expect(image_editor).to have_position(x: 24, y: 75)

    image_editor.reposition
    image_editor.nudge(:right, :escape)
    expect(image_editor).to have_no_adjustment
    expect(image_editor).to have_position(x: 24, y: 75)
  end

  it "keeps the author's image position when clicking away and allows one-step undo" do
    visit("/latest")
    editor.enter
    image_editor.select_section
    image_editor.set_position(x: 25, y: 75)
    image_editor.reposition
    image_editor.nudge(:right, :right, :down)
    image_editor.select_image
    expect(image_editor).to have_no_adjustment
    expect(image_editor).to have_position(x: 27, y: 76)

    image_editor.undo
    expect(image_editor).to have_position(x: 25, y: 75)
    image_editor.redo
    expect(image_editor).to have_position(x: 27, y: 76)

    image_editor.select_section
    image_editor.reposition
    image_editor.nudge(:left)
    image_editor.click_outside_blocks
    expect(image_editor).to have_no_selected_block
    expect(image_editor).to have_no_adjustment
    expect(image_editor).to have_position(x: 26, y: 76)
    image_editor.undo
    expect(image_editor).to have_position(x: 27, y: 76)
  end

  it "lets an author resize an image with handles around its frame" do
    visit("/latest")
    editor.enter
    image_editor.select_image

    expect(image_editor).to have_positioned_resize_handles
    screenshot_marker(label: "wireframe-image-resize", only: :desktop)
    dimensions = image_editor.image_dimensions
    image_editor.resize_image(x: -60, y: -36)
    expect(image_editor).to have_image_dimensions(
      width: dimensions["width"] - 60,
      height: dimensions["height"] - 36,
    )

    image_editor.select_section
    image_editor.select_image
    expect(image_editor).to have_image_dimensions(
      width: dimensions["width"] - 60,
      height: dimensions["height"] - 36,
    )
    expect(image_editor).to have_positioned_resize_handles
  end

  it "lets an author open compact image actions and continue in the inspector" do
    visit("/latest")
    editor.enter
    image_editor.select_image
    expect(image_editor).to have_no_image_menu
    image_editor.select_image
    expect(image_editor).to have_no_image_menu
    image_editor.hide_image_settings
    image_editor.open_image_menu
    expect(image_editor).to have_compact_image_menu
    expect(image_editor).to have_inline_menu_fit
    expect(image_editor).to have_grouped_image_actions
    expect(image_editor).to have_toolbar_anchored_menu
    screenshot_marker(label: "wireframe-image-compact-menu", only: :desktop)
    image_editor.set_menu_fit
    expect(image_editor).to have_image_fit
    dimensions = image_editor.image_dimensions
    image_editor.change_image(file_from_fixtures("logo.png", "images").path)
    expect(image_editor).to have_uploaded_image
    expect(image_editor).to have_image_fit
    expect(image_editor).to have_image_dimensions(
      width: dimensions["width"],
      height: dimensions["height"],
    )
    image_editor.reposition_from_menu
    expect(image_editor).to have_no_image_menu
    expect(image_editor).to have_adjustment
    image_editor.cancel_adjustment
    expect(image_editor).to have_no_adjustment
    image_editor.open_image_menu
    image_editor.show_more_image_settings
    expect(image_editor).to have_no_image_menu
    expect(image_editor).to have_focused_image_settings
  end

  it "lets an author edit the grid that controls a nested image's size" do
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    grid_key = image_editor.owning_grid_key
    expect(image_editor).to have_grid_sizing_notice
    expect(image_editor).to have_no_independent_frame_controls
    screenshot_marker(label: "wireframe-image-grid-sizing", only: :desktop)
    image_editor.edit_grid
    expect(image_editor).to have_selected_grid(grid_key)
  end

  it "identifies the visible source when an image has both color variants" do
    dark_scheme = ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
    Theme.find_default.update!(dark_color_scheme_id: dark_scheme.id)
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.open_image_menu
    expect(image_editor).to have_matching_variant_action
    expect(image_editor).to have_shared_composition_hint
    screenshot_marker(label: "wireframe-image-compact-menu-variants", only: :desktop)
    expect(image_editor).to have_grouped_image_actions
  end

  it "takes an author to image settings when the inspector is already open on another tab" do
    visit("/latest")
    editor.enter
    image_editor.select_image
    image_editor.open_image_menu
    expect(image_editor).to have_no_inspector_shortcut
    image_editor.close_image_menu
    image_editor.show_raw_json
    image_editor.open_image_menu
    image_editor.show_more_image_settings
    expect(image_editor).to have_focused_image_settings
    image_editor.open_image_menu
    expect(image_editor).to have_no_inspector_shortcut
  end

  it "lets an author add and replace the visible dark image without changing the default source" do
    image_editor.use_short_viewport
    dark_scheme = ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
    Theme.find_default.update!(dark_color_scheme_id: dark_scheme.id)
    image_editor.use_color_mode("dark")
    visit("/latest")
    editor.enter
    image_editor.select_image
    image_editor.open_image_menu
    expect(image_editor).to have_default_image_fallback
    image_editor.add_dark_image(file_from_fixtures("logo.png", "images").path)
    expect(image_editor).to have_visible_dark_upload
    expect(image_editor).to have_shared_composition_hint
    first_dark_source = image_editor.dark_source

    cdp.with_paused_request(%r{/uploads\.json}) do |request|
      image_editor.change_image(file_from_fixtures("logo.jpg", "images").path)
      request.wait
      image_editor.use_color_mode("light")
      expect(image_editor).to have_visible_default_image
      request.resume
      expect(image_editor).to have_replaced_dark_source(first_dark_source)
    end
    expect(image_editor).to have_visible_default_image
    image_editor.use_color_mode("dark")
    expect(image_editor).to have_visible_dark_upload
    expect(image_editor).to have_change_dark_image
    expect(image_editor).to have_inspector_shortcut
    image_editor.show_more_image_settings
    expect(image_editor).to have_focused_dark_image_settings
  end

  it "renders shared image frames on the published page" do
    visit("/latest")
    expect(page).to have_css(".d-block-section .d-block-image-frame")
    expect(page).to have_css(".d-block-image__caption", text: "A shared image frame")
    screenshot_marker(label: "wireframe-image-published")
  end
end
