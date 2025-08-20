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

  let(:foundation_scheme_a) do
    Fabricate(:color_scheme, name: "Foundation scheme a", theme: Theme.foundation_theme)
  end
  let(:foundation_scheme_b) do
    Fabricate(:color_scheme, name: "Foundation scheme b", theme: Theme.foundation_theme)
  end
  let(:horizon_scheme_a) do
    Fabricate(:color_scheme, name: "Horizon scheme a", theme: Theme.horizon_theme)
  end
  let(:horizon_scheme_b) do
    Fabricate(:color_scheme, name: "Horizon scheme b", theme: Theme.horizon_theme)
  end
  let(:custom_scheme_a) { Fabricate(:color_scheme, name: "Custom scheme a") }
  let(:custom_scheme_b) { Fabricate(:color_scheme, name: "Custom scheme b") }
  let(:selectable_foundation_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme a",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_foundation_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable foundation scheme b",
      theme: Theme.foundation_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_a) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme a",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_horizon_theme_scheme_b) do
    Fabricate(
      :color_scheme,
      name: "Selectable horizon scheme b",
      theme: Theme.horizon_theme,
      user_selectable: true,
    )
  end
  let(:selectable_custom_scheme_a) do
    Fabricate(:color_scheme, name: "Selectable custom scheme a", user_selectable: true)
  end
  let(:selectable_custom_scheme_b) do
    Fabricate(:color_scheme, name: "Selectable custom scheme b", user_selectable: true)
  end
  let(:default_light_scheme) { Fabricate(:color_scheme, name: "Default light") }
  let(:default_dark_scheme) { Fabricate(:color_scheme, name: "Default dark") }
  let(:create_color_palette_modal) { PageObjects::Modals::CreateColorPalette.new }

  before { sign_in(admin) }

  describe "filtering" do
    it "shows filters when there are more than 8 color schemes" do
      visit("/admin/customize/colors")

      expect(page).to have_css(".admin-filter-controls__input")
    end

    it "can filter by text search" do
      visit("/admin/customize/colors")

      find(".admin-filter-controls__input").fill_in(with: user_selectable_palette.name)

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

      find(".admin-filter-controls__input").fill_in(with: "bananas")

      expect(page).to have_css(".admin-filter-controls__no-results")
      expect(page).to have_css("button", text: I18n.t("admin_js.admin.plugins.filters.reset"))
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

    it "can toggle user selectable status" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") { find(".btn-flat").click }

      expect(page).to have_css(".dropdown-menu")
      click_button(I18n.t("admin_js.admin.customize.theme.user_selectable_button_label"))

      within("[data-palette-id='#{regular_palette.id}']") do
        expect(page).to have_css(".theme-card__badge.--selectable")
      end
    end

    it "can set as light and dark default for theme" do
      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") { find(".btn-flat").click }

      expect(page).to have_css(".dropdown-menu")

      click_button(
        I18n.t(
          "admin_js.admin.customize.colors.set_default_light",
          { theme: Theme.find_default.name },
        ),
      )

      within("[data-palette-id='#{regular_palette.id}']") do
        expect(page).to have_css(
          ".theme-card__badge.--default",
          text: I18n.t("admin_js.admin.customize.colors.default_light_badge.text").upcase,
        )
      end

      within("[data-palette-id='#{regular_palette.id}']") { find(".btn-flat").click }

      expect(page).to have_css(".dropdown-menu")

      click_button(
        I18n.t(
          "admin_js.admin.customize.colors.set_default_dark",
          { theme: Theme.find_default.name },
        ),
      )

      within("[data-palette-id='#{regular_palette.id}']") do
        expect(page).to have_css(
          ".theme-card__badge.--default",
          text: I18n.t("admin_js.admin.customize.colors.default_both_badge.text").upcase,
        )
      end
    end
  end

  describe "CSS variables" do
    it "generates CSS variables for color schemes" do
      visit("/admin/customize/colors")

      palette_item = find("[data-palette-id='#{regular_palette.id}'] .color-palette__preview")

      expect(palette_item[:style]).to include("--primary--preview:")
      expect(palette_item[:style]).to include("--secondary--preview:")
      expect(palette_item[:style]).to include("--tertiary--preview:")
    end
  end

  describe "live preview functionality" do
    it "does not show toast when live preview is available" do
      admin.user_option.update!(
        theme_ids: [Theme.find_default.id],
        color_scheme_id: -1,
        dark_scheme_id: -1,
      )

      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") { find(".btn-flat").click }

      expect(page).to have_css(".dropdown-menu")

      click_button(
        I18n.t(
          "admin_js.admin.customize.colors.set_default_light",
          { theme: Theme.find_default.name },
        ),
      )

      expect(page).to have_no_css(".fk-d-default-toast.-success")
    end

    it "shows toast when admin cannot see live preview" do
      custom_scheme = Fabricate(:color_scheme, name: "Custom Scheme")
      admin.user_option.update!(
        theme_ids: [Theme.find_default.id],
        color_scheme_id: custom_scheme.id,
      )

      visit("/admin/customize/colors")

      within("[data-palette-id='#{regular_palette.id}']") { find(".btn-flat").click }

      expect(page).to have_css(".dropdown-menu")

      click_button(
        I18n.t(
          "admin_js.admin.customize.colors.set_default_light",
          { theme: Theme.find_default.name },
        ),
      )

      expected_message =
        I18n.t(
          "admin_js.admin.customize.colors.set_default_success",
          schemeName: regular_palette.name,
          themeName: Theme.find_default.name,
        )
      expect(toasts).to have_success(expected_message)
    end
  end

  describe "sort" do
    before do
      ColorScheme.delete_all
      foundation_scheme_a
      foundation_scheme_b
      horizon_scheme_a
      horizon_scheme_b
      custom_scheme_a
      custom_scheme_b
      selectable_foundation_scheme_a
      selectable_foundation_scheme_b
      selectable_horizon_theme_scheme_a
      selectable_horizon_theme_scheme_b
      selectable_custom_scheme_a
      selectable_custom_scheme_b
      default_light_scheme
      default_dark_scheme
      Theme.horizon_theme.update!(
        color_scheme: default_light_scheme,
        dark_color_scheme: default_dark_scheme,
      )
    end
    it "sorts schemes in order: selectable, custom, current default theme, alphabetical for horizon theme" do
      SiteSetting.default_theme_id = Theme.horizon_theme.id
      visit("/admin/customize/colors")
      color_schemes = page.all(".color-palette__details h3").map(&:text)
      expect(color_schemes).to eq(
        [
          "Default light",
          "Default dark",
          "Selectable custom scheme a",
          "Selectable custom scheme b",
          "Selectable horizon scheme a",
          "Selectable horizon scheme b",
          "Selectable foundation scheme a",
          "Selectable foundation scheme b",
          "Custom scheme a",
          "Custom scheme b",
          "Horizon scheme a",
          "Horizon scheme b",
          "Foundation scheme a",
          "Foundation scheme b",
          "Light (default)",
        ],
      )
    end

    it "sorts schemes in order: selectable, custom, current default theme, alphabetical for foundation theme" do
      SiteSetting.default_theme_id = Theme.foundation_theme.id
      visit("/admin/customize/colors")
      color_schemes = page.all(".color-palette__details h3").map(&:text)
      expect(color_schemes).to eq(
        [
          "Light (default)",
          "Selectable custom scheme a",
          "Selectable custom scheme b",
          "Selectable foundation scheme a",
          "Selectable foundation scheme b",
          "Selectable horizon scheme a",
          "Selectable horizon scheme b",
          "Custom scheme a",
          "Custom scheme b",
          "Default dark",
          "Default light",
          "Foundation scheme a",
          "Foundation scheme b",
          "Horizon scheme a",
          "Horizon scheme b",
        ],
      )
    end
  end

  it "can create new color palette from custom palette" do
    visit("/admin/customize/colors")

    page.find(".d-page-action-button").click

    create_color_palette_modal.base_dropdown.select_row_by_name("Theme Palette")

    create_color_palette_modal.create_button.click

    expect(page).to have_current_path(%r{/admin/customize/colors/\d+})
    expect(page).to have_no_css(".revert")
  end
end
