# frozen_string_literal: true

RSpec.describe PatreonGroupRewardFilter do
  it "belongs to group and patreon_reward" do
    record = Fabricate(:patreon_group_reward_filter)
    expect(record.group).to be_present
    expect(record.patreon_reward).to be_present
  end

  it "enforces uniqueness of group-reward pair" do
    group = Fabricate(:group)
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: reward)

    expect {
      PatreonGroupRewardFilter.create!(group: group, patreon_reward: reward)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "cascades when group is deleted" do
    group = Fabricate(:group)
    Fabricate(:patreon_group_reward_filter, group: group)

    expect { group.destroy }.to change { PatreonGroupRewardFilter.count }.by(-1)
  end

  it "cascades when reward is deleted" do
    reward = Fabricate(:patreon_reward)
    Fabricate(:patreon_group_reward_filter, patreon_reward: reward)

    expect { reward.destroy }.to change { PatreonGroupRewardFilter.count }.by(-1)
  end
end
