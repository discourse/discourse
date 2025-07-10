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
end
