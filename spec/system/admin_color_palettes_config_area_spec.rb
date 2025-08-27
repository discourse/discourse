# frozen_string_literal: true

describe "Admin Color Palettes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:palette) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette") }

  let(:config_area) { PageObjects::Pages::AdminColorPalettesConfigArea.new }
  let(:create_color_palette_modal) { PageObjects::Modals::CreateColorPalette.new }

  before { sign_in(admin) }

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
    create_color_palette_modal.base_dropdown.expand
    expect(page).to have_css(".color-palette-picker-row")
    create_color_palette_modal.base_dropdown.select_row_by_name("A Test Palette")

    create_color_palette_modal.create_button.click

    expect(page).to have_current_path(%r{/admin/config/colors/\d+})
    expect(page).to have_no_css(".revert")
  end
end
