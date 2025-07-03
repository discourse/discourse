# frozen_string_literal: true

require_relative "./page_objects/components/user_color_palette_selector"

describe "Horizon theme | User color palette selector", type: :system do
  let(:set_theme_as_default) { true }
  let!(:theme) do
    horizon_theme = upload_theme(set_theme_as_default: set_theme_as_default)
    horizon_theme.color_schemes.update_all(user_selectable: true)
    horizon_theme
  end
  fab!(:current_user) { Fabricate(:user) }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:palette_selector) { PageObjects::Components::UserColorPaletteSelector.new }
  let(:interface_color_mode) { PageObjects::Components::InterfaceColorMode.new }
  let(:interface_color_selector) do
    PageObjects::Components::InterfaceColorSelector.new(".sidebar-footer-actions")
  end
  let(:marigold_palette) { theme.color_schemes.find_by(name: "Marigold") }
  let(:marigold_palette_dark) { theme.color_schemes.find_by(name: "Marigold Dark") }

  before { SiteSetting.interface_color_selector = "sidebar_footer" }

  it "does not show the sidebar button if there are no user-selectable color palettes" do
    ColorScheme.update_all(user_selectable: false)
    visit "/"
    expect(page).to have_no_css(palette_selector.sidebar_footer_button_css)
  end

  describe "for logged in user" do
    before { sign_in(current_user) }

    it "can open the user color palette menu and select a palette, which is preseved on reload" do
      visit "/"
      palette_selector.open_palette_menu
      palette_selector.click_palette_menu_item(marigold_palette.name)

      expect(palette_selector).to have_no_palette_menu
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_loaded_css
      expect(palette_selector).to have_tertiary_color(marigold_palette)

      page.refresh
      expect(palette_selector).to have_selected_palette(marigold_palette)
    end

    it "uses the dark version of the palette if the user selects dark mode" do
      visit "/"
      palette_selector.open_palette_menu
      palette_selector.click_palette_menu_item(marigold_palette.name)

      expect(palette_selector).to have_no_palette_menu
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_loaded_css
      expect(palette_selector).to have_computed_color("oklch(0.92 0.0708528 68.5036)")

      interface_color_selector.expand
      interface_color_selector.dark_option.click
      expect(interface_color_mode).to have_dark_mode_forced
      expect(palette_selector).to have_computed_color("oklch(0.481966 0.0354264 68.5036)")

      page.refresh
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_computed_color("oklch(0.481966 0.0354264 68.5036)")
    end

    context "when the theme is not default but is selected by a user" do
      let(:set_theme_as_default) { false }

      it "can open the user color palette menu and select a palette, which is preseved on reload" do
        theme.update!(user_selectable: true)
        current_user.user_option.update!(theme_ids: [theme.id])
        visit "/"
        palette_selector.open_palette_menu
        palette_selector.click_palette_menu_item(marigold_palette.name)

        expect(palette_selector).to have_no_palette_menu
        expect(palette_selector).to have_selected_palette(marigold_palette)
        expect(palette_selector).to have_loaded_css
        expect(palette_selector).to have_tertiary_color(marigold_palette)
      end
    end
  end

  describe "for anon" do
    it "can open the user color palette menu and select a palette, which is preseved on reload" do
      visit "/"
      palette_selector.open_palette_menu
      palette_selector.click_palette_menu_item(marigold_palette.name)

      expect(palette_selector).to have_no_palette_menu
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_loaded_css
      expect(palette_selector).to have_tertiary_color(marigold_palette)
    end

    it "uses the dark version of the palette if the user selects dark mode, which is preserved on reload" do
      visit "/"
      palette_selector.open_palette_menu
      palette_selector.click_palette_menu_item(marigold_palette.name)

      expect(palette_selector).to have_no_palette_menu
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_loaded_css
      expect(palette_selector).to have_computed_color("oklch(0.92 0.0708528 68.5036)")

      interface_color_selector.expand
      interface_color_selector.dark_option.click
      expect(interface_color_mode).to have_dark_mode_forced
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_loaded_css
      expect(palette_selector).to have_computed_color("oklch(0.481966 0.0354264 68.5036)")

      page.refresh
      expect(palette_selector).to have_selected_palette(marigold_palette)
      expect(palette_selector).to have_computed_color("oklch(0.481966 0.0354264 68.5036)")
    end
  end
end
