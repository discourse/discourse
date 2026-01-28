# frozen_string_literal: true

RSpec.describe SystemThemesManager do
  # This is necessary since the theme settings migrations happen
  # when `SystemThemesManager.sync!` is called as part of app boot,
  # and we want to ensure that any previous migration records for the core themes are cleared to properly test idempotency.
  before { ThemeSettingsMigration.where(theme_id: Theme::CORE_THEMES.values).delete_all }

  it "is idempotent" do
    Theme.delete_all
    expect { SystemThemesManager.sync! }.to change { Theme.system.count }.by(2)
    expect { SystemThemesManager.sync! }.not_to change { Theme.count }
    expect(Theme.horizon_theme.color_scheme.user_selectable).to be false
    expect(
      Theme.horizon_theme.color_schemes.where(name: "Horizon Dark").first.user_selectable,
    ).to be false
    expect(Theme.horizon_theme.color_schemes.where(user_selectable: false).count).to eq(12)
  end

  it "renables themes" do
    SystemThemesManager.sync!
    Theme.horizon_theme.update_column(:enabled, false)
    SystemThemesManager.sync!
    expect(Theme.horizon_theme.reload.enabled).to be true
  end

  it "sets up the default light and dark palettes for Horizon on the initial install" do
    Theme.delete_all

    expect { SystemThemesManager.sync! }.to change { Theme.system.count }.by(2)

    expect(Theme.horizon_theme.color_scheme.name).to eq("Horizon")
    expect(Theme.horizon_theme.dark_color_scheme.name).to eq("Horizon Dark")

    Theme.horizon_theme.update!(color_scheme: nil)
    Theme.horizon_theme.update!(dark_color_scheme: nil)

    expect { SystemThemesManager.sync! }.not_to change { Theme.system.count }

    expect(Theme.horizon_theme.color_scheme).to eq(nil)
    expect(Theme.horizon_theme.dark_color_scheme).to eq(nil)
  end
end
