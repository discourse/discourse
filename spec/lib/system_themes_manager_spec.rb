# frozen_string_literal: true

RSpec.describe SystemThemesManager do
  it "is idempotent" do
    Theme.delete_all
    expect { SystemThemesManager.sync! }.to change { Theme.system.count }.by(2)
    expect { SystemThemesManager.sync! }.not_to change { Theme.count }
    expect(Theme.horizon_theme.color_scheme.user_selectable).to be true
    expect(
      Theme.horizon_theme.color_schemes.where(name: "Horizon Dark").first.user_selectable,
    ).to be true
    expect(Theme.horizon_theme.color_schemes.where(user_selectable: true).count).to eq(2)
    expect(Theme.horizon_theme.color_schemes.where(user_selectable: false).count).to eq(10)
  end

  it "renables themes" do
    SystemThemesManager.sync!
    Theme.horizon_theme.update_column(:enabled, false)
    SystemThemesManager.sync!
    expect(Theme.horizon_theme.reload.enabled).to be true
  end

  it "marks Horizon's default color palettes as user selectable only the first time the theme is installed" do
    Theme.delete_all

    expect { SystemThemesManager.sync! }.to change { Theme.system.count }.by(2)

    expect(Theme.horizon_theme.color_scheme.user_selectable).to eq(true)
    expect(Theme.horizon_theme.dark_color_scheme.user_selectable).to eq(true)

    Theme.horizon_theme.color_scheme.update!(user_selectable: false)
    Theme.horizon_theme.dark_color_scheme.update!(user_selectable: false)

    expect { SystemThemesManager.sync! }.not_to change { Theme.system.count }

    expect(Theme.horizon_theme.color_scheme.reload.user_selectable).to eq(false)
    expect(Theme.horizon_theme.dark_color_scheme.reload.user_selectable).to eq(false)
  end
end
