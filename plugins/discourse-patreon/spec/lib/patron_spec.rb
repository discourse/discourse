# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Patreon::Patron do
  Fabricator(:patreon_user_info, class_name: :user_associated_account) do
    provider_name "patreon"
    user
  end

  let(:patrons) do
    { "111111" => "foo@bar.com", "111112" => "boo@far.com", "111113" => "roo@aar.com" }
  end
  let(:pledges) { { "111111" => "100", "111112" => "500" } }
  let(:rewards) do
    {
      "0" => {
        title: "All Patrons",
        amount_cents: "0",
      },
      "4589" => {
        title: "Sponsers",
        amount_cents: "1000",
      },
    }
  end
  let(:reward_users) { { "0" => %w[111111 111112], "4589" => ["111112"] } }
  let(:titles) { { "111111" => "All Patrons", "111112" => "All Patrons, Sponsers" } }

  before do
    Patreon.set("users", patrons)
    Patreon.set("pledges", pledges)
    Patreon.set("rewards", rewards)
    Patreon.set("reward-users", reward_users)
  end

  it "should find local users matching Patreon user info" do
    Fabricate(:user, email: "foo@bar.com")
    Fabricate(:patreon_user_info, provider_uid: "111112")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(2)

    local_users.each do |user_id, patreon_id|
      user = User.find(user_id)
      expect(described_class.attr("email", user)).to eq(patrons[patreon_id])
      expect(described_class.attr("amount_cents", user)).to eq(pledges[patreon_id])
      expect(described_class.attr("rewards", user)).to eq(titles[patreon_id])
    end
  end

  it "should find local users matching email address without case-sensitivity" do
    patrons["111111"] = "Foo@bar.com"
    Patreon.set("users", patrons)
    Fabricate(:user, email: "foo@bar.com")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(1)
  end

  describe "sync groups" do
    let(:ouser) { Fabricate(:patreon_user_info, provider_uid: "111112") }
    let(:group1) { Fabricate(:group) }
    let(:group2) { Fabricate(:group) }

    before do
      filters = { group1.id.to_s => ["0"], group2.id.to_s => ["4589"] }
      Patreon.set("filters", filters)
    end

    it "should sync all Patreon users" do
      user = Fabricate(:user, email: "foo@bar.com")
      described_class.sync_groups
      expect(group1.users.to_a - [ouser.user, user]).to eq([])
      expect(group2.users.to_a - [ouser.user]).to eq([])
    end

    it "should sync by Patreon id" do
      described_class.sync_groups_by(patreon_id: ouser.provider_uid)
      expect(group1.users.to_a).to eq([ouser.user])
      expect(group2.users.to_a).to eq([ouser.user])
    end
  end
end
