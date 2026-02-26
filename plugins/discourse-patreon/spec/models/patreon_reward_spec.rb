# frozen_string_literal: true

RSpec.describe PatreonReward do
  it "validates presence of patreon_id" do
    reward = PatreonReward.new(title: "Test")
    expect(reward).not_to be_valid
    expect(reward.errors[:patreon_id]).to be_present
  end

  it "validates presence of title" do
    reward = PatreonReward.new(patreon_id: "123")
    expect(reward).not_to be_valid
    expect(reward.errors[:title]).to be_present
  end

  it "validates uniqueness of patreon_id" do
    Fabricate(:patreon_reward, patreon_id: "123")
    reward = PatreonReward.new(patreon_id: "123", title: "Dup")
    expect(reward).not_to be_valid
    expect(reward.errors[:patreon_id]).to be_present
  end

  it "cascades destroy to patreon_patron_rewards" do
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_patron_reward, patreon_reward: reward)

    expect { reward.destroy }.to change { PatreonPatronReward.count }.by(-1)
  end

  it "cascades destroy to patreon_group_reward_filters" do
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_group_reward_filter, patreon_reward: reward)

    expect { reward.destroy }.to change { PatreonGroupRewardFilter.count }.by(-1)
  end

  it "has many patreon_patrons through patreon_patron_rewards" do
    reward = Fabricate(:patreon_reward)
    patron = Fabricate(:patreon_patron)
    Fabricate(:patreon_patron_reward, patreon_reward: reward, patreon_patron: patron)

    expect(reward.patreon_patrons).to include(patron)
  end
end
