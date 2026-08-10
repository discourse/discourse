# frozen_string_literal: true

RSpec.describe "Styleguide color mode selector" do
  fab!(:admin)

  let!(:dark_scheme) { ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"]) }

  let(:styleguide) { PageObjects::Pages::Styleguide.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:color_mode) { PageObjects::Components::InterfaceColorMode.new }

  before do
    SiteSetting.styleguide_enabled = true
    Theme.find_default.update!(dark_color_scheme_id: dark_scheme.id)
    sign_in(admin)
  end

  # The selector is torn down and rebuilt on every styleguide navigation, so it has to read the
  # mode that is actually applied rather than the one it last set.
  it "keeps showing the applied color mode after the reader opens a section" do
    styleguide.visit_index

    styleguide.select_color_mode("dark")
    expect(color_mode).to have_dark_mode_forced

    sidebar.click_link_in_section("styleguide-category-atoms", "styleguide-section-buttons")

    expect(styleguide).to have_color_mode("dark")

    styleguide.select_color_mode("light")
    expect(color_mode).to have_light_mode_forced
  end

  it "lets the reader go back to following the system preference" do
    styleguide.visit_index

    styleguide.select_color_mode("dark")
    expect(color_mode).to have_dark_mode_forced

    styleguide.select_color_mode("auto")

    expect(color_mode).to have_auto_color_mode
    expect(styleguide).to have_color_mode("auto")
  end
end
