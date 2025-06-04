# frozen_string_literal: true

RSpec.describe SystemThemesManager do
  it "is idempotent" do
    Theme.destroy_all
    expect { SystemThemesManager.sync! }.to change { Theme.count }.by(2)
    expect { SystemThemesManager.sync! }.not_to change { Theme.count }
  end
end
