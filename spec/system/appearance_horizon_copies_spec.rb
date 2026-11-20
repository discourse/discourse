# frozen_string_literal: true

RSpec.describe "Horizon appearance copies" do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  before do
    SystemThemesManager.sync_theme!("horizon")
    Theme.horizon_theme.set_default!
    sign_in(admin)
  end

  let(:change) do
    result =
      AppearanceChange::DraftTheme.call(
        params: {
          name: "Rounded Horizon",
          base_theme_id: Theme.horizon_theme.id,
          light_colors:
            ColorScheme.base_colors.transform_values do
              AppearanceStyles::PaletteColors.normalize(it)
            end,
          dark_colors: ColorScheme::BUILT_IN_SCHEMES[:Dark],
          styles: {
            variables: {
              "--d-button-border-radius" => "20px",
            },
          },
        },
        guardian: admin.guardian,
      )
    expect(result).to run_successfully
    result[:appearance_change]
  end

  it "keeps Horizon's layout and JavaScript in a styled preview without changing the live theme" do
    visit("/latest?preview_theme_id=#{change.theme_id}")
    expect(page).to have_css(".experimental-screen")
    expect(page).to have_css(".topic-list-item[data-topic-id='#{topic.id}'] td.hc-topic-card")
    expect(page).to have_css(".sidebar-wrapper")
    expect(
      page.evaluate_script(
        "getComputedStyle(document.documentElement).getPropertyValue('--d-button-border-radius').trim()",
      ),
    ).to eq("20px")
    screenshot_marker(label: "horizon-styled-preview")
    expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)
  end

  it "lets an admin explicitly detach a copy before editing it by hand" do
    theme = change.theme
    PageObjects::Pages::AdminCustomizeThemes.new.visit(theme)
    expect(page).to have_content(
      I18n.t("admin_js.admin.customize.theme.horizon_synced_description"),
    )
    expect(page).to have_no_css(".included-components-setting")
    click_button(I18n.t("admin_js.admin.customize.theme.horizon_detach"))
    dialog = PageObjects::Components::Dialog.new
    expect(dialog).to be_open
    dialog.click_yes
    expect(page).to have_no_button(I18n.t("admin_js.admin.customize.theme.horizon_detach"))
    expect(page).to have_css(".included-components-setting")
    expect(theme.reload.appearance_sync).to be_nil
  end
end
