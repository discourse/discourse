# frozen_string_literal: true

describe "Admin Color Palettes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:palette_1) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette 1") }
  fab!(:palette_2) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette 2") }

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

    max_id = ColorScheme.maximum(:id) + 1
    config_area.create_button.click
    create_color_palette_modal.base_dropdown.select_row_by_name("Grey Amber")
    create_color_palette_modal.create_button.click

    expect(page).to have_current_path("/admin/config/colors/#{max_id}")
    expect(edit_config_area.palette_id).to eq(max_id)
  end
end
