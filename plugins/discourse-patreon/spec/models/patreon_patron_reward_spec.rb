# frozen_string_literal: true

RSpec.describe PatreonPatronReward do
  it "belongs to patreon_patron and patreon_reward" do
    record = Fabricate(:patreon_patron_reward)
    expect(record.patreon_patron).to be_present
    expect(record.patreon_reward).to be_present
  end

  it "enforces uniqueness of patron-reward pair" do
    patron = Fabricate(:patreon_patron)
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: reward)

    expect {
      PatreonPatronReward.create!(patreon_patron: patron, patreon_reward: reward)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
