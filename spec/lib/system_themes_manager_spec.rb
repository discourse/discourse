# frozen_string_literal: true

RSpec.describe SystemThemesManager do
  it "is idempotent" do
    Theme.delete_all
    expect { SystemThemesManager.sync! }.to change { Theme.system.count }.by(2)
    expect { SystemThemesManager.sync! }.not_to change { Theme.count }
  end
end
