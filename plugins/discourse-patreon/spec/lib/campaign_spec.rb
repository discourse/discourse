# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Patreon::Campaign do
  before do
    campaigns_url =
      "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100"
    pledges_url =
      "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=100&sort=created"
    content = { status: 200, headers: { "Content-Type" => "application/json" } }

    campaigns = content.merge(body: get_patreon_response("campaigns.json"))
    pledges = content.merge(body: get_patreon_response("pledges.json"))

    stub_request(:get, campaigns_url).to_return(campaigns)
    stub_request(:get, pledges_url).to_return(pledges)
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
  end

  it "should update campaigns and group users data" do
    expect { described_class.update! }.to change { Group.count }.by(1).and change {
            Badge.count
          }.by(1)

    expect(PatreonPatron.where.not(amount_cents: nil).count).to eq(3)
    expect(PatreonPatron.where.not(declined_since: nil).count).to eq(2)
    expect(PatreonReward.count).to eq(5)
    expect(PatreonPatron.where.not(email: nil).count).to eq(3)
    expect(PatreonReward.find_by(patreon_id: "0").patreon_patrons.count).to eq(3)
    expect(PatreonGroupRewardFilter.select(:group_id).distinct.count).to eq(1)

    expect {
      PatreonPatron
        .where.not(email: nil)
        .pluck(:patreon_id, :email)
        .each do |id, email|
          cf = Fabricate(:user, email: email).custom_fields
          expect(cf["patreon_id"]).to eq(id)
        end
    }.to change { GroupUser.count }.by(3)
  end

  it "should not prune rewards that have admin-configured group filters" do
    described_class.update!

    # Create a reward not in API response but with an admin filter
    stale_reward =
      Fabricate(:patreon_reward, patreon_id: "stale_123", title: "Stale Reward", amount_cents: 200)
    group = Fabricate(:group)
    Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: stale_reward)

    # Also create a reward not in API response WITHOUT a filter
    orphan_reward =
      Fabricate(
        :patreon_reward,
        patreon_id: "orphan_456",
        title: "Orphan Reward",
        amount_cents: 100,
      )

    # Run sync again — stale reward should be kept, orphan should be pruned
    described_class.update!

    expect(PatreonReward.find_by(patreon_id: "stale_123")).to be_present
    expect(PatreonGroupRewardFilter.where(patreon_reward: stale_reward).count).to eq(1)
    expect(PatreonReward.find_by(patreon_id: "orphan_456")).to be_nil
  end
end
