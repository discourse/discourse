# frozen_string_literal: true

RSpec.describe Badge do
  after { Voice::BadgeGranterHooks.disable_all! }

  it "seeds the voice badges without taking over a name the site already uses" do
    DB.exec("DELETE FROM badges WHERE name = 'Explorer'")
    existing =
      Fabricate(
        :badge,
        name: "Explorer",
        system: false,
        query: "SELECT 1",
        description: "Handed out by us",
      )

    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
    existing.reload

    expect(existing.system).to eq(false)
    expect(existing.query).to eq("SELECT 1")
    expect(existing[:description]).to eq("Handed out by us")
    expect(Badge.find_by(name: "Nomad").system).to eq(true)
  end
end
