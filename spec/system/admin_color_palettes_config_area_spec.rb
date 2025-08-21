# frozen_string_literal: true

describe "Admin Color Palettes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:palette_1) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette 1") }
  fab!(:palette_2) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette 2") }
  let(:dark_palette) { ColorScheme.find_by(name: "Dark") }

  let(:config_area) { PageObjects::Pages::AdminColorPalettesConfigArea.new }
  let(:edit_config_area) { PageObjects::Pages::AdminColorPaletteConfigArea.new }
  let(:create_color_palette_modal) { PageObjects::Modals::CreateColorPalette.new }

  before { sign_in(admin) }

  it "can navigate between different palettes" do
    config_area.visit

    config_area.palette(palette_1.id).click
    expect(edit_config_area.palette_id).to eq(palette_1.id)
    expect(page).to have_current_path("/admin/config/colors/#{palette_1.id}")

    config_area.palette(palette_2.id).click
    expect(edit_config_area.palette_id).to eq(palette_2.id)
    expect(page).to have_current_path("/admin/config/colors/#{palette_2.id}")
  end

  it "can create new color palettes" do
    config_area.visit

    config_area.create_button.click
    create_color_palette_modal.base_dropdown.select_row_by_name("Grey Amber")
    create_color_palette_modal.create_button.click

    expect(page).to have_current_path(%r{/admin/config/colors/\d+})
  end

  it "can create new color palette from custom palette" do
    config_area.visit

    config_area.create_button.click
    create_color_palette_modal.base_dropdown.select_row_by_name("A Test Palette 2")

    create_color_palette_modal.create_button.click

    expect(page).to have_current_path(%r{/admin/config/colors/\d+})
    expect(page).to have_no_css(".revert")
  end

  it "can toggle light and dark palette as default on default theme" do
    edit_config_area.visit(palette_1.id)
    page.has_text?(
      I18n.t(
        "admin_js.admin.config_areas.color_palettes.color_options.toggle_default_light_on_theme",
        themeName: "Foundation",
      ),
    )
    expect(edit_config_area.default_on_theme_field.disabled?).to eq(false)
    edit_config_area.default_on_theme_field.toggle
    edit_config_area.form.submit

    edit_config_area.visit(palette_2.id)
    expect(edit_config_area.default_on_theme_field.disabled?).to eq(true)

    edit_config_area.visit(dark_palette.id)
    page.has_text?(
      I18n.t(
        "admin_js.admin.config_areas.color_palettes.color_options.toggle_default_dark_on_theme",
        themeName: "Foundation",
      ),
    )
    expect(edit_config_area.default_on_theme_field.disabled?).to eq(false)
    edit_config_area.default_on_theme_field.toggle
    edit_config_area.form.submit
  end
end
