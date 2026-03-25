# frozen_string_literal: true

require "openssl"
require "json"
require_relative "../spec_helper"

RSpec.describe Patreon::PatreonWebhookController do
  before do
    SiteSetting.patreon_enabled = true
    SiteSetting.login_required = true
    Jobs.run_immediately!
  end

  describe "index" do
    describe "header checking" do
      it "returns a 403 error without header params" do
        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) { post "/patreon/webhook" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Missing event header")
      end

      it "returns a 403 error with unknown event" do
        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) do
          post "/patreon/webhook",
               headers: {
                 "X-Patreon-Event": "foo:bar",
                 "X-Patreon-Signature": "foo",
               }
        end

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Unknown event: foo:bar")
      end

      it "returns a 403 error with invalid signature" do
        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) do
          post "/patreon/webhook",
               headers: {
                 "X-Patreon-Event": "members:pledge:create",
                 "X-Patreon-Signature": "foo",
               }
        end

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Invalid signature")
      end

      it "returns a 403 error when webhook secret is blank" do
        SiteSetting.patreon_webhook_secret = ""
        body = get_patreon_response("member.json")
        digest = OpenSSL::Digest.new("MD5")
        forged_signature = OpenSSL::HMAC.hexdigest(digest, "", body)

        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) do
          post "/patreon/webhook",
               params: body,
               headers: {
                 "X-Patreon-Event": "members:pledge:create",
                 "X-Patreon-Signature": forged_signature,
               }
        end

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Invalid signature")
      end
    end

    describe "v2 member webhooks" do
      let(:body) { get_patreon_response("member.json") }
      let(:digest) { OpenSSL::Digest.new("MD5") }
      let(:secret) { SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET" }

      before do
        Patreon.set(
          "rewards",
          "0": {
            title: "All Patrons",
            amount_cents: 0,
          },
          "999999": {
            title: "Premium",
            amount_cents: 1000,
          },
        )
      end

      def add_member
        member_data = JSON.parse(body)
        Patreon::Pledge.create!(member_data.dup, adapter: Patreon::ApiVersion::V2)
        member_data
      end

      def post_request(body, event)
        post "/patreon/webhook",
             params: body,
             headers: {
               "X-Patreon-Event": "members:pledge:#{event}",
               "X-Patreon-Signature": OpenSSL::HMAC.hexdigest(digest, secret, body),
             }
      end

      it "for event members:pledge:create" do
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        Patreon.set("filters", group.id.to_s => ["0"])

        expect { post_request(body, "create") }.to change { Patreon::Pledge.all.keys.count }.by(
          1,
        ).and change { Patreon::Patron.all.keys.count }.by(1).and change {
                      Patreon::RewardUser.all.keys.count
                    }.by(2)

        expect(group.users).to include(user)
      end

      it "for event members:pledge:update" do
        member_data = add_member
        member = member_data["data"]
        member["attributes"]["currently_entitled_amount_cents"] = 987
        patron_id = member["relationships"]["user"]["data"]["id"]
        member_data = JSON.pretty_generate(member_data)

        expect(Patreon.get("pledges")[patron_id]).to eq(250)
        post_request(member_data, "update")
        expect(Patreon.get("pledges")[patron_id]).to eq(987)
      end

      it "for event members:pledge:delete" do
        add_member
        tier_id =
          JSON.parse(body)["data"]["relationships"]["currently_entitled_tiers"]["data"][0]["id"]

        expect { post_request(body, "delete") }.to change { Patreon::Pledge.all.keys.count }.by(
          -1,
        ).and change { Patreon::Patron.all.keys.count }.by(-1).and change {
                      Patreon::RewardUser.all[tier_id].count
                    }.by(-1)
      end
    end

    describe "v1 pledge webhooks" do
      let(:body) { get_patreon_response("v1/pledge.json") }
      let(:digest) { OpenSSL::Digest.new("MD5") }
      let(:secret) { SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET" }

      before do
        Patreon.set(
          "rewards",
          "0": {
            title: "All Patrons",
            amount_cents: 0,
          },
          "999999": {
            title: "Premium",
            amount_cents: 1000,
          },
        )
      end

      def add_pledge
        pledge_data = JSON.parse(body)
        Patreon::Pledge.create!(pledge_data.dup, adapter: Patreon::ApiVersion::V1)
        pledge_data
      end

      def post_request(body, event)
        post "/patreon/webhook",
             params: body,
             headers: {
               "X-Patreon-Event": "pledges:#{event}",
               "X-Patreon-Signature": OpenSSL::HMAC.hexdigest(digest, secret, body),
             }
      end

      it "for event pledges:create" do
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        Patreon.set("filters", group.id.to_s => ["0"])

        expect { post_request(body, "create") }.to change { Patreon::Pledge.all.keys.count }.by(
          1,
        ).and change { Patreon::Patron.all.keys.count }.by(1).and change {
                      Patreon::RewardUser.all.keys.count
                    }.by(2)

        expect(group.users).to include(user)
      end

      it "for event pledges:update" do
        pledge_data = add_pledge
        pledge = pledge_data["data"]
        pledge["attributes"]["amount_cents"] = 987
        patron_id = pledge["relationships"]["patron"]["data"]["id"]
        pledge_data = JSON.pretty_generate(pledge_data)

        expect(Patreon.get("pledges")[patron_id]).to eq(250)
        post_request(pledge_data, "update")
        expect(Patreon.get("pledges")[patron_id]).to eq(987)
      end

      it "for event pledges:delete" do
        pledge_data = add_pledge
        reward_id = pledge_data["data"]["relationships"]["reward"]["data"]["id"]

        expect { post_request(body, "delete") }.to change { Patreon::Pledge.all.keys.count }.by(
          -1,
        ).and change { Patreon::Patron.all.keys.count }.by(-1).and change {
                      Patreon::RewardUser.all[reward_id].count
                    }.by(-1)
      end
    end
  end
end
