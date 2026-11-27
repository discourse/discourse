# frozen_string_literal: true

describe "Viewing another user's interface preferences" do
  fab!(:admin)
  fab!(:user)
  fab!(:admin_theme) { Fabricate(:theme, user_selectable: true) }
  fab!(:admin_theme_palette) do
    Fabricate(
      :color_scheme,
      base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"],
      theme_id: admin_theme.id,
    )
  end
  fab!(:user_palette) do
    Fabricate(
      :color_scheme,
      base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"],
      user_selectable: true,
    )
  end

  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before do
    admin_theme.theme_modifier_set.update!(only_theme_color_schemes: true)
    admin.user_option.update!(theme_ids: [admin_theme.id])
    sign_in(admin)
  end

  it "lists palettes from the viewed user's theme and keeps them on save" do
    user.user_option.update!(
      theme_ids: [SiteSetting.default_theme_id],
      color_scheme_id: user_palette.id,
      dark_scheme_id: nil,
    )

    user_preferences_interface_page.visit(user)

    expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_value(
      user_palette.id,
    )

    user_preferences_interface_page.save_changes

    page.refresh

    expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_value(
      user_palette.id,
    )
  end
end
