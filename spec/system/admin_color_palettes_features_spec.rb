# frozen_string_literal: true

describe "Admin Color Palettes Features", type: :system do
  fab!(:admin)
  fab!(:theme) { Fabricate(:theme, name: "Test Theme") }
  fab!(:user_selectable_palette) do
    Fabricate(:color_scheme, name: "User Selectable", user_selectable: true)
  end
  fab!(:theme_palette) { Fabricate(:color_scheme, name: "Theme Palette", theme: theme) }
  fab!(:regular_palette) do
    Fabricate(:color_scheme, name: "Regular Palette", user_selectable: false)
  end

  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    sign_in(admin)
    # filter requires 8 palettes to show
    6.times { |i| Fabricate(:color_scheme, name: "Extra Palette #{i}") }
  end

  describe "filtering" do
    it "shows filters when there are more than 8 color schemes" do
      visit("/admin/customize/colors")

      expect(page).to have_css(".color-palette__filters")
      expect(page).to have_css(".admin-filter__input")
    end

    it "can filter by text search" do
      visit("/admin/customize/colors")

      find(".admin-filter__input").fill_in(with: user_selectable_palette.name)

      expect(page).to have_css("[data-palette-id='#{user_selectable_palette.id}']")
      expect(page).to have_no_css("[data-palette-id='#{regular_palette.id}']")
    end

    it "can filter by type" do
      visit("/admin/customize/colors")

      select_kit = PageObjects::Components::DSelect.new(".d-select")
      select_kit.select("user_selectable")

      expect(page).to have_css("[data-palette-id='#{user_selectable_palette.id}']")
      expect(page).to have_no_css("[data-palette-id='#{regular_palette.id}']")
      expect(page).to have_no_css(".color-palette:not([data-palette-id])")
    end

    it "shows no results state" do
      visit("/admin/customize/colors")

      find(".admin-filter__input").fill_in(with: "bananas")

      expect(page).to have_css(".color-palette__no-results")
      expect(page).to have_css(
        "button",
        text: I18n.t("admin_js.admin.customize.colors.filters.reset"),
      )
    end
  end

  describe "color palette list items" do
    it "shows palette details" do
      visit("/admin/customize/colors")

      expect(page).to have_css("[data-palette-id='#{user_selectable_palette.id}']")
      expect(page).to have_css("[data-palette-id='#{theme_palette.id}']")
      expect(page).to have_css("[data-palette-id='#{regular_palette.id}']")
    end

    it "shows user selectable badge" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{user_selectable_palette.id}']") do
        expect(page).to have_css(".theme-card__badge.--selectable")
      end
    end

    it "shows theme link for theme palettes" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{theme_palette.id}']") { expect(page).to have_link(theme.name) }
    end

    it "can set palette as default and shows toast" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") do
        find(".btn-flat").click
        click_button(I18n.t("admin_js.admin.customize.colors.set_default"))
      end

      expect(toasts).to have_success(I18n.t("admin_js.admin.customize.colors.saved_refreshing"))
    end

    it "can toggle user selectable status" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") do
        find(".btn-flat").click
        click_button(I18n.t("admin_js.admin.customize.theme.user_selectable_button_label"))
      end

      expect(regular_palette.reload.user_selectable).to be true
    end
  end

  describe "CSS variables" do
    it "generates CSS variables for color schemes" do
      visit("/admin/customize/colors")

      palette_item = find("[data-palette-id='#{regular_palette.id}']")

      expect(palette_item[:style]).to include("--primary--preview:")
      expect(palette_item[:style]).to include("--secondary--preview:")
      expect(palette_item[:style]).to include("--tertiary--preview:")
    end
  end
end
