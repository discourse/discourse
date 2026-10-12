# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Patreon::Campaign do
  shared_examples "campaign sync" do
    it "updates campaigns and group membership data" do
      expect { described_class.update! }.to change { Group.count }.by(1)

      expect(Group.find_by(name: "patrons")).to be_present
      expect(Badge.find_by(name: "Patron")).to be_present
      expect(Patreon.get("pledges").count).to eq(3)
      expect(Patreon::Pledge::Decline.all.count).to eq(2)
      expect(Patreon.get("rewards").count).to eq(expected_rewards_count)
      expect(Patreon.get("rewards")["0"]).to include(
        "id" => "0",
        "title" => "All Patrons",
        "amount_cents" => 0,
      )
      expect(Patreon.get("users").count).to eq(3)
      expect(Patreon.get("reward-users")["0"].count).to eq(3)
      expect(Patreon.get("filters").count).to eq(1)

      expect {
        Patreon
          .get("users")
          .each do |id, email|
            cf = Fabricate(:user, email: email).custom_fields
            expect(cf["patreon_id"]).to eq(id)
          end
      }.to change { GroupUser.count }.by(3)
    end
  end

  context "with API v1" do
    let(:expected_rewards_count) { 5 }

    before do
      campaigns_url =
        "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100"
      pledges_url =
        "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=100&sort=created"
      content = { status: 200, headers: { "Content-Type" => "application/json" } }

      stub_request(:get, campaigns_url).to_return(
        content.merge(body: get_patreon_response("v1/campaigns.json")),
      )
      stub_request(:get, pledges_url).to_return(
        content.merge(body: get_patreon_response("v1/pledges.json")),
      )
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_api_version = "1"
      SiteSetting.patreon_declined_pledges_grace_period_days = 7
    end

    include_examples "campaign sync"
  end

  context "with API v2" do
    let(:expected_rewards_count) { 4 }
    let(:members_response) { JSON.parse(get_patreon_response("members.json")) }

    before do
      campaigns_url =
        "https://www.patreon.com/api/oauth2/v2/campaigns?include=tiers,creator&fields%5Bcampaign%5D=created_at,name,patron_count&fields%5Btier%5D=title,amount_cents,created_at"
      members_url =
        "https://www.patreon.com/api/oauth2/v2/campaigns/0000000/members?include=currently_entitled_tiers,user&fields%5Bmember%5D=full_name,last_charge_date,last_charge_status,currently_entitled_amount_cents,patron_status,email&fields%5Buser%5D=email,full_name&fields%5Btier%5D=title,amount_cents,created_at&page%5Bcount%5D=1000"
      content = { status: 200, headers: { "Content-Type" => "application/json" } }

      stub_request(:get, campaigns_url).to_return(
        content.merge(body: get_patreon_response("campaigns.json")),
      )
      stub_request(:get, members_url).to_return { content.merge(body: members_response.to_json) }
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_api_version = "2"
      SiteSetting.patreon_declined_pledges_grace_period_days = 7
    end

    include_examples "campaign sync"

    it "syncs an unlinked user when emails are only present on member records" do
      members_response["included"].each do |entry|
        entry["attributes"]["email"] = nil if entry["type"] == "user"
      end
      members_response["data"].first["attributes"]["email"] = "Foo@bar.com"
      user = Fabricate(:user, email: "foo@bar.com")
      group = Fabricate(:group)
      Patreon.set("filters", group.id.to_s => ["0"])

      Patreon::Patron.update!

      expect(Patreon::Patron.all).to eq(
        "111111" => "foo@bar.com",
        "111112" => "boo@far.com",
        "111113" => "roo@aar.com",
      )
      expect(group.users).to contain_exactly(user)
      expect(user.reload.custom_fields["patreon_id"]).to eq("111111")
    end

    it "prefers member emails and falls back to included user emails" do
      members_response["data"].first["attributes"]["email"] = "Member@example.com"
      members_response["data"][1]["attributes"]["email"] = nil
      members_response["data"][2]["attributes"]["email"] = ""

      described_class.update!

      expect(Patreon::Patron.all).to eq(
        "111111" => "member@example.com",
        "111112" => "boo@far.com",
        "111113" => "roo@aar.com",
      )
    end
  end
end
