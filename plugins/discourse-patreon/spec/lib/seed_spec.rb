# frozen_string_literal: true

RSpec.describe Patreon::Seed do
  it "should seed contents correctly" do
    described_class.seed_content!
    group = Group.find_by(name: "patrons")
    expect(group).to be_present
    expect(group.flair_upload).to be_present
    expect(Badge.find_by(name: "Patron")).to be_present

    all_patrons_reward = PatreonReward.find_by(patreon_id: "0")
    expect(all_patrons_reward).to be_present
    expect(all_patrons_reward.title).to eq("All Patrons")

    expect(PatreonGroupRewardFilter.count).to eq(1)
    filter = PatreonGroupRewardFilter.first
    expect(filter.group).to eq(group)
    expect(filter.patreon_reward).to eq(all_patrons_reward)
  end

  it "should not raise error if group already exists" do
    group = Fabricate(:group, name: "patrons")
    described_class.seed_content!

    expect(PatreonGroupRewardFilter.count).to eq(1)
    expect(PatreonGroupRewardFilter.first.group).to eq(group)
  end

  it "should not raise error if badge already exists" do
    Fabricate(:badge, name: "Patron")
    described_class.seed_content!
  end
end
