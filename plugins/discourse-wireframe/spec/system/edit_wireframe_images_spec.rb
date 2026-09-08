# frozen_string_literal: true

describe "Edit wireframe images" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }
  let(:image_editor) { PageObjects::Components::WireframeImageEditor.new }
  let(:cdp) { PageObjects::CDP.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

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
    expect(image_editor).to have_aligned_unit_controls
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
    expect(image_editor).to have_compact_source_rows
    expect(image_editor).to have_aligned_unit_controls
    expect(image_editor).to have_clear_section_hierarchy
    expect(image_editor).to have_no_independent_frame_controls
    screenshot_marker(label: "wireframe-image-grid-sizing", only: :desktop)
    image_editor.edit_grid
    expect(image_editor).to have_selected_grid(grid_key)
    screenshot_marker(label: "wireframe-image-owning-grid", only: :desktop)
  end

  it "lets an author replace and remove image sources from compact inspector choosers" do
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.open_source
    expect(image_editor).to have_compact_source_chooser
    screenshot_marker(label: "wireframe-image-source-chooser", only: :desktop)

    image_editor.upload_default_source(file_from_fixtures("logo.png", "images").path)
    expect(image_editor).to have_uploaded_grid_image
    expect(image_editor).to have_compact_source_chooser
    image_editor.open_source(variant: :dark)
    screenshot_marker(label: "wireframe-image-dark-source-chooser", only: :desktop)
    image_editor.remove_dark_source
    expect(image_editor).to have_no_dark_grid_image
    expect(image_editor).to have_uploaded_grid_image
    image_editor.remove_default_source
    expect(image_editor).to have_empty_image_chooser
    screenshot_marker(label: "wireframe-image-empty-source", only: :desktop)
  end

  it "lets an author move between consistent block inspectors" do
    image_editor.use_tall_viewport
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    expect(image_editor).to have_clear_section_hierarchy
    screenshot_marker(label: "wireframe-inspector-feedback-image", only: :desktop)
    image_editor.show_placement_fields
    screenshot_marker(label: "wireframe-inspector-feedback-placement", only: :desktop)
    image_editor.select_heading
    expect(image_editor).to have_inspector_field("Level")
    screenshot_marker(label: "wireframe-inspector-feedback-heading", only: :desktop)
    image_editor.select_paragraph
    expect(image_editor).to have_inspector_field("Text")
    screenshot_marker(label: "wireframe-inspector-feedback-paragraph", only: :desktop)
    image_editor.select_button
    expect(image_editor).to have_inspector_field("Style")
    screenshot_marker(label: "wireframe-inspector-feedback-button", only: :desktop)
    image_editor.select_grid_image
    image_editor.open_source
    image_editor.remove_default_source
    expect(image_editor).to have_empty_image_chooser
    screenshot_marker(label: "wireframe-inspector-feedback-empty", only: :desktop)
  end

  it "replaces both image variants by dropping onto closed source rows" do
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.use_inspector_width(240)
    cdp.with_paused_request(%r{/uploads\.json}) do |request|
      image_editor.drop_source(file_from_fixtures("logo.png", "images").path)
      request.wait
      expect(image_editor).to have_closed_source_progress
      screenshot_marker(label: "wireframe-inspector-closeout-uploading", only: :desktop)
      request.resume
    end
    expect(image_editor).to have_uploaded_grid_image
    expect(image_editor).to have_no_source_progress
    image_editor.drop_source(file_from_fixtures("logo.png", "images").path, variant: :dark)
    expect(image_editor).to have_uploaded_closed_sources
    image_editor.with_failed_upload do
      image_editor.drop_source(file_from_fixtures("logo.png", "images").path)
      expect(dialog).to be_open
      dialog.click_ok
      expect(image_editor).to have_closed_source_error
      expect(image_editor).to have_contained_inspector_content
      screenshot_marker(label: "wireframe-inspector-closeout-error", only: :desktop)
    end
    image_editor.open_source
    image_editor.remove_default_source
    expect(image_editor).to have_empty_image_chooser
    expect(image_editor).to have_contained_inspector_content
    screenshot_marker(label: "wireframe-inspector-closeout-empty", only: :desktop)
  end

  it "keeps image dimensions and controls readable on an Arabic page" do
    SiteSetting.default_locale = "ar"
    image_editor.use_tall_viewport
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.stretch_grid_image
    image_editor.use_inspector_width(240)
    expect(image_editor).to have_rtl_page
    expect(image_editor).to have_position_marker(x: 50, y: 50)
    image_editor.set_position(x: 25, y: 75)
    expect(image_editor).to have_position_marker(x: 25, y: 75)
    image_editor.choose_top_left_position
    expect(image_editor).to have_top_left_position
    expect(image_editor).to have_ordered_source_dimensions
    expect(image_editor).to have_contained_inspector_content
    expect(image_editor).to have_paired_grid_coordinates
    expect(image_editor).to have_aligned_inspector_selections
    screenshot_marker(label: "wireframe-inspector-closeout-arabic", only: :desktop)
  end

  it "keeps longer translated image controls inside the minimum inspector" do
    SiteSetting.default_locale = "de"
    {
      "tab_args" => "Blockeinstellungen",
      "tab_conditions" => "Anzeigebedingungen",
      "image.fit" => "Einpassen",
      "image.fill" => "Ausfüllen",
      "image.zoom_short" => "Vergrößerung",
      "image.reposition" => "Bild auf der Arbeitsfläche positionieren",
    }.each do |key, value|
      TranslationOverride.upsert!("de", "js.wireframe.inspector.#{key}", value)
    end
    image_editor.use_tall_viewport
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.use_inspector_width(240)
    expect(image_editor).to have_inspector_translation("Blockeinstellungen")
    expect(image_editor).to have_contained_inspector_content
    screenshot_marker(label: "wireframe-inspector-closeout-long-labels", only: :desktop)
  end

  it "keeps the zoom track on the same subdued surface as the position pad" do
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.use_inspector_width(240)
    expect(image_editor).to have_themed_zoom_track
    image_editor.change_zoom_with_keyboard(:end)
    expect(image_editor).to have_image_zoom(250)
    image_editor.change_zoom_with_keyboard(:home)
    expect(image_editor).to have_image_zoom(100)
    screenshot_marker(label: "wireframe-inspector-closeout-slider", only: :desktop)
  end

  it "keeps the minimum inspector usable with zoom-equivalent viewport scaling" do
    image_editor.use_tall_viewport
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.use_inspector_width(240)
    [1.25, 2].each do |scale|
      image_editor.with_zoomed_viewport(scale) do
        expect(image_editor).to have_zoomed_viewport(scale)
        expect(image_editor).to have_contained_inspector_content
        expect(image_editor).to have_aligned_unit_controls(compact: true)
        expect(image_editor).to have_grouped_composition_controls(
          compact: true,
          full_width_actions: true,
        )
        screenshot_marker(
          label: "wireframe-inspector-closeout-zoom-#{scale}",
          only: :desktop,
          preserve_viewport: true,
        )
        expect(image_editor).to have_zoomed_viewport(scale)
      end
    end
  end

  it "keeps composition controls grouped across inspector widths in either direction" do
    image_editor.use_tall_viewport
    visit("/latest")
    editor.enter
    image_editor.select_grid_image
    image_editor.stretch_grid_image
    image_editor.set_position(x: 100, y: 100)
    [240, 260, 320, 480].each do |width|
      image_editor.use_inspector_width(width)
      screenshot_marker(label: "wireframe-composition-layout-#{width}", only: :desktop)
      expect(image_editor).to have_aligned_unit_controls(compact: width == 240)
      expect(image_editor).to have_grouped_composition_controls(
        compact: width == 240,
        full_width_actions: width <= 260,
      )
      expect(image_editor).to have_contained_inspector_actions
      expect(image_editor).to have_paired_grid_coordinates
      expect(image_editor).to have_readable_coordinate_controls
      expect(image_editor).to have_aligned_inspector_selections
    end
    image_editor.use_rtl_inspector
    [240, 260, 480].each do |width|
      image_editor.use_inspector_width(width)
      expect(image_editor).to have_aligned_unit_controls(compact: width == 240)
      expect(image_editor).to have_grouped_composition_controls(
        compact: width == 240,
        full_width_actions: width <= 260,
      )
      expect(image_editor).to have_contained_inspector_actions
      expect(image_editor).to have_paired_grid_coordinates
      expect(image_editor).to have_readable_coordinate_controls
      expect(image_editor).to have_aligned_inspector_selections
    end
    screenshot_marker(label: "wireframe-composition-layout-rtl", only: :desktop)
    image_editor.use_inspector_width(240)
    image_editor.show_placement_fields
    screenshot_marker(label: "wireframe-composition-layout-placement", only: :desktop)
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
