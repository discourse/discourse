# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Patreon group access", type: :request do
  fab!(:group)
  fab!(:category) { Fabricate(:private_category, group: group) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:private_post) { Fabricate(:post, topic: topic, raw: "Patron-only content") }

  let(:user) { Fabricate(:user, email: "roo@aar.com") }
  let(:patreon_id) { "32187" }
  let(:reward_ids) { ["0"] }
  let(:tiers) { [] }
  let(:member_attributes) do
    {
      "patron_status" => nil,
      "currently_entitled_amount_cents" => 0,
      "last_charge_status" => nil,
      "last_charge_date" => nil,
    }
  end
  let(:member) do
    JSON.parse(get_patreon_response("member.json")).deep_merge(
      "data" => {
        "attributes" => member_attributes,
        "relationships" => {
          "currently_entitled_tiers" => {
            "data" => tiers,
          },
        },
      },
    )
  end
  let(:campaign_members) { member.merge("data" => [member.fetch("data")]) }
  let(:event) { "members:create" }
  let(:webhook_body) { JSON.generate(member) }
  let(:webhook_headers) do
    {
      "X-Patreon-Event" => event,
      "X-Patreon-Signature" =>
        OpenSSL::HMAC.hexdigest("MD5", SiteSetting.patreon_webhook_secret, webhook_body),
    }
  end

  before do
    freeze_time Time.utc(2026, 9, 22)
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_api_version = "2"
    SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET"
    SiteSetting.patreon_creator_access_token = "access-token"
    SiteSetting.patreon_creator_refresh_token = "refresh-token"
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
    Jobs.run_immediately!
    Patreon.set("filters", group.id.to_s => reward_ids)
    Patreon.set("rewards", "0" => { "title" => "All Patrons", "amount_cents" => 0 })
  end

  shared_examples "denies patron content" do
    it "denies access to the private topic" do
      synchronize
      sign_in(user)
      get "/t/#{topic.id}.json"

      aggregate_failures do
        expect(group.users).not_to include(user)
        expect(response.status).to eq(404)
        expect(response.body).not_to include(private_post.raw)
      end
    end
  end

  shared_examples "allows patron content" do
    it "allows access to the private topic" do
      synchronize
      sign_in(user)
      get "/t/#{topic.id}.json"

      aggregate_failures do
        expect(group.users).to include(user)
        expect(response.status).to eq(200)
        expect(response.body).to include(private_post.raw)
      end
    end
  end

  context "when membership arrives through a webhook" do
    subject(:synchronize) do
      post "/patreon/webhook", params: webhook_body, headers: webhook_headers
      expect(response.status).to eq(200)
    end

    before { user }

    context "when the member is free" do
      include_examples "denies patron content"
    end

    context "when the member is a former patron" do
      let(:member_attributes) { super().merge("patron_status" => "former_patron") }

      include_examples "denies patron content"
    end

    context "when the member is active with a zero entitlement amount" do
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }

      include_examples "allows patron content"
    end

    context "when the patron is linked through OAuth with a different email" do
      let(:user) { Fabricate(:user) }

      before do
        Fabricate(
          :user_associated_account,
          user: user,
          provider_name: "patreon",
          provider_uid: patreon_id,
        )
      end

      include_examples "denies patron content"
    end

    context "when a free member has cached access" do
      before do
        group.add(user)
        Patreon.set("pledges", patreon_id => 0)
        Patreon.set("users", patreon_id => user.email)
        Patreon.set("reward-users", "0" => [patreon_id])
      end

      include_examples "denies patron content"
    end

    context "when an update ends the patron's entitlement" do
      let(:event) { "members:update" }

      before do
        group.add(user)
        Patreon::Patron.update_local_user(user, patreon_id)
        Patreon.set("pledges", patreon_id => 250)
        Patreon.set("users", patreon_id => user.email)
        Patreon.set("reward-users", "0" => [patreon_id], "999999" => [patreon_id])
        Patreon.set("rewards", "999999" => { "title" => "Premium", "amount_cents" => 250 })
      end

      include_examples "denies patron content"
    end

    context "when another campaign updates the patron's membership" do
      let(:event) { "members:update" }
      let(:reward_ids) { ["999998"] }
      let(:tiers) { [{ "id" => "999999", "type" => "tier" }] }
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }
      let(:member) do
        super().deep_merge(
          "data" => {
            "relationships" => {
              "campaign" => {
                "data" => {
                  "id" => "another-campaign",
                  "type" => "campaign",
                },
              },
            },
          },
        )
      end

      before do
        group.add(user)
        Patreon.set("pledges", patreon_id => 250)
        Patreon.set("users", patreon_id => user.email)
        Patreon.set("rewards", "0" => {}, "999998" => {}, "999999" => {})
        Patreon.set(
          "reward-users",
          "0" => [patreon_id],
          "999998" => [patreon_id],
          "999999" => [patreon_id],
        )
      end

      include_examples "allows patron content"
    end
  end

  context "when an API v1 create event is repeated before its reward is cached" do
    subject(:synchronize) do
      post "/patreon/webhook", params: webhook_body, headers: webhook_headers
      expect(response.status).to eq(200)
    end

    let(:event) { "pledges:create" }
    let(:webhook_body) { get_patreon_response("v1/pledge.json") }

    before do
      user
      post "/patreon/webhook", params: webhook_body, headers: webhook_headers
      expect(response.status).to eq(200)
    end

    include_examples "allows patron content"
  end

  context "when a member creates a Discourse account" do
    subject(:synchronize) { user }

    before do
      post "/patreon/webhook", params: webhook_body, headers: webhook_headers
      expect(response.status).to eq(200)
    end

    context "when the member is free" do
      include_examples "denies patron content"
    end

    context "when the member is active" do
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }

      include_examples "allows patron content"
    end

    context "when an active member qualifies for a later group mapping" do
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }
      let(:unmatched_group) { Fabricate(:group) }

      before do
        Patreon.set("filters", unmatched_group.id.to_s => ["999999"], group.id.to_s => ["0"])
      end

      include_examples "allows patron content"
    end

    context "when the declined pledge is beyond its grace period" do
      let(:member_attributes) do
        super().merge(
          "patron_status" => "declined_patron",
          "last_charge_status" => "Declined",
          "last_charge_date" => "2026-09-14T00:00:00Z",
        )
      end

      include_examples "denies patron content"
    end

    context "when the declined pledge is on the final grace day" do
      let(:member_attributes) do
        super().merge(
          "patron_status" => "declined_patron",
          "last_charge_status" => "Declined",
          "last_charge_date" => "2026-09-15T00:00:00Z",
        )
      end

      include_examples "allows patron content"
    end

    context "when the declined pledge has no charge date" do
      let(:member_attributes) do
        super().merge("patron_status" => "declined_patron", "last_charge_status" => "Declined")
      end

      include_examples "denies patron content"
    end

    context "when the declined status has no charge details" do
      let(:member_attributes) { super().merge("patron_status" => "declined_patron") }

      include_examples "denies patron content"
    end
  end

  context "when the scheduled job refreshes an existing membership" do
    subject(:synchronize) { Jobs::PatreonSyncPatronsToGroups.new.execute({}) }

    let(:members_status) { 200 }
    let(:members_response) { JSON.generate(campaign_members) }

    before do
      group.add(user)
      Patreon::Patron.update_local_user(user, patreon_id)
      Patreon.set("pledges", patreon_id => 0)
      Patreon.set("users", patreon_id => user.email)
      Patreon.set("reward-users", "0" => [patreon_id])

      stub_request(
        :get,
        "https://www.patreon.com#{Patreon::ApiVersion::V2.campaign_data_url}",
      ).to_return(status: 200, body: get_patreon_response("campaigns.json"))
      stub_request(
        :get,
        "https://www.patreon.com#{Patreon::ApiVersion::V2.members_data_url("0000000")}",
      ).to_return(status: members_status, body: members_response)
    end

    context "when the member is free" do
      include_examples "denies patron content"
    end

    context "when the campaign has no members" do
      let(:campaign_members) { super().merge("data" => [], "included" => []) }

      include_examples "denies patron content"
    end

    context "when the member is active" do
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }

      include_examples "allows patron content"
    end

    context "when the declined pledge is beyond its grace period" do
      let(:member_attributes) do
        super().merge(
          "patron_status" => "declined_patron",
          "last_charge_status" => "Declined",
          "last_charge_date" => "2026-09-14T00:00:00Z",
        )
      end

      include_examples "denies patron content"
    end

    context "when the active member appears on a later page" do
      let(:campaign_members) do
        super().merge(
          "data" => [
            member.fetch("data").deep_merge(
              "id" => "another-member",
              "relationships" => {
                "user" => {
                  "data" => {
                    "id" => "another-patron",
                  },
                },
              },
            ),
          ],
          "included" => [],
          "meta" => {
            "pagination" => {
              "cursors" => {
                "next" => "next-page",
              },
            },
          },
        )
      end
      let(:next_page) do
        member
          .deep_merge("data" => { "attributes" => { "patron_status" => "active_patron" } })
          .then { |response| response.merge("data" => [response.fetch("data")]) }
      end

      before do
        stub_request(
          :get,
          "https://www.patreon.com#{Patreon::ApiVersion::V2.members_data_url("0000000", "next-page")}",
        ).to_return(status: 200, body: JSON.generate(next_page))
      end

      include_examples "allows patron content"
    end

    context "when the provider rejects the access token" do
      let(:members_status) { 401 }
      let(:members_response) { "" }

      include_examples "allows patron content"
    end

    context "when a webhook revokes membership during a later page request" do
      let(:event) { "members:pledge:delete" }
      let(:member_attributes) { super().merge("patron_status" => "active_patron") }
      let(:campaign_members) do
        super().merge("meta" => { "pagination" => { "cursors" => { "next" => "next-page" } } })
      end
      let(:next_page) do
        {
          "data" => [
            member.fetch("data").deep_merge(
              "id" => "another-member",
              "attributes" => {
                "email" => "another-patron@example.com",
              },
              "relationships" => {
                "user" => {
                  "data" => {
                    "id" => "another-patron",
                  },
                },
              },
            ),
          ],
        }
      end

      before do
        stub_request(
          :get,
          "https://www.patreon.com#{Patreon::ApiVersion::V2.members_data_url("0000000", "next-page")}",
        ).to_return do
          post "/patreon/webhook", params: webhook_body, headers: webhook_headers
          expect(response.status).to eq(200)
          { status: 200, body: JSON.generate(next_page) }
        end
      end

      include_examples "denies patron content"
    end

    context "when a later page fails" do
      let(:campaign_members) do
        super().merge("meta" => { "pagination" => { "cursors" => { "next" => "next-page" } } })
      end

      before do
        stub_request(
          :get,
          "https://www.patreon.com#{Patreon::ApiVersion::V2.members_data_url("0000000", "next-page")}",
        ).to_return(status: 401)
      end

      include_examples "allows patron content"
    end

    context "when an API v1 member request fails" do
      before do
        SiteSetting.patreon_api_version = "1"
        stub_request(
          :get,
          "https://api.patreon.com#{Patreon::ApiVersion::V1.campaign_data_url}",
        ).to_return(status: 200, body: get_patreon_response("v1/campaigns.json"))
        stub_request(
          :get,
          "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=100&sort=created",
        ).to_return(status: 401)
      end

      include_examples "allows patron content"

      it "preserves the cached membership" do
        expect { synchronize }.not_to change { Patreon::Pledge.all }
      end
    end
  end
end
