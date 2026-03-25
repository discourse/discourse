# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Patreon::Campaign do
  before do
    campaigns_url =
      "https://www.patreon.com/api/oauth2/v2/campaigns?include=tiers,creator&fields%5Bcampaign%5D=created_at,name,patron_count&fields%5Btier%5D=title,amount_cents,created_at"
    members_url =
      "https://www.patreon.com/api/oauth2/v2/campaigns/0000000/members?include=currently_entitled_tiers,user&fields%5Bmember%5D=full_name,last_charge_date,last_charge_status,currently_entitled_amount_cents,patron_status,email&fields%5Buser%5D=email,full_name&fields%5Btier%5D=title,amount_cents,created_at&page%5Bcount%5D=1000"
    content = { status: 200, headers: { "Content-Type" => "application/json" } }

    campaigns = content.merge(body: get_patreon_response("campaigns.json"))
    members = content.merge(body: get_patreon_response("members.json"))

    stub_request(:get, campaigns_url).to_return(campaigns)
    stub_request(:get, members_url).to_return(members)
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
  end

  it "should update campaigns and group users data" do
    expect { described_class.update! }.to change { Group.count }.by(1)

    expect(Group.find_by(name: "patrons")).to be_present
    expect(Badge.find_by(name: "Patron")).to be_present
    expect(Patreon.get("pledges").count).to eq(3)
    expect(Patreon::Pledge::Decline.all.count).to eq(2)
    expect(Patreon.get("rewards").count).to eq(4)
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
