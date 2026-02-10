# frozen_string_literal: true

RSpec.describe PatreonPatron do
  it "validates presence of patreon_id" do
    patron = PatreonPatron.new(email: "test@example.com")
    expect(patron).not_to be_valid
    expect(patron.errors[:patreon_id]).to be_present
  end

  it "validates uniqueness of patreon_id" do
    Fabricate(:patreon_patron, patreon_id: "123")
    patron = PatreonPatron.new(patreon_id: "123")
    expect(patron).not_to be_valid
    expect(patron.errors[:patreon_id]).to be_present
  end

  it "cascades destroy to patreon_patron_rewards" do
    patron = Fabricate(:patreon_patron)
    Fabricate(:patreon_patron_reward, patreon_patron: patron)

    expect { patron.destroy }.to change { PatreonPatronReward.count }.by(-1)
  end

  it "has many patreon_rewards through patreon_patron_rewards" do
    patron = Fabricate(:patreon_patron)
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: reward)

    expect(patron.patreon_rewards).to include(reward)
  end
end
