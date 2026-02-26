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
        expect_not_enqueued_with(job: :sync_patron_groups) { post "/patreon/webhook" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Missing event header")
      end

      it "returns a 403 error with unknown event" do
        expect_not_enqueued_with(job: :sync_patron_groups) do
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
        SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET"

        expect_not_enqueued_with(job: :sync_patron_groups) do
          post "/patreon/webhook",
               headers: {
                 "X-Patreon-Event": "pledges:create",
                 "X-Patreon-Signature": "foo",
               }
        end

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to contain_exactly("Invalid signature")
      end

      it "returns a 403 error when webhook secret is not configured" do
        SiteSetting.patreon_webhook_secret = ""

        expect_not_enqueued_with(job: :sync_patron_groups) do
          post "/patreon/webhook",
               params: "{}",
               headers: {
                 "X-Patreon-Event": "pledges:create",
                 "X-Patreon-Signature": "anything",
               }
        end

        expect(response.status).to eq(403)
      end

      it "returns a 403 error when signature header is missing" do
        SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET"

        expect_not_enqueued_with(job: :sync_patron_groups) do
          post "/patreon/webhook", headers: { "X-Patreon-Event": "pledges:create" }
        end

        expect(response.status).to eq(403)
      end
    end

    describe "enqueue job" do
      let(:body) { get_patreon_response("pledge.json") }
      let(:digest) { OpenSSL::Digest.new("MD5") }
      let(:secret) { SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET" }

      before do
        Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
        Fabricate(:patreon_reward, patreon_id: "999999", title: "Premium", amount_cents: 1000)
      end

      def add_pledge
        pledge_data = JSON.parse(body)
        Patreon::Pledge.create!(pledge_data.dup)

        pledge_data
      end

      def post_request(body, event, type = "pledges")
        post "/patreon/webhook",
             params: body,
             headers: {
               "X-Patreon-Event": "#{type}:#{event}",
               "X-Patreon-Signature": OpenSSL::HMAC.hexdigest(digest, secret, body),
             }
      end

      it "for event pledge:create" do
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        all_patrons_reward = PatreonReward.find_by(patreon_id: "0")
        Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: all_patrons_reward)

        expect { post_request(body, "create") }.to change { PatreonPatron.count }.by(1).and change {
                PatreonPatronReward.count
              }

        expect(group.users).to include(user)
      end

      it "for event members:pledge:create" do
        body = get_patreon_response("member.json")
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        all_patrons_reward = PatreonReward.find_by(patreon_id: "0")
        Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: all_patrons_reward)

        expect { post_request(body, "create", "members:pledge") }.to change {
          PatreonPatron.count
        }.by(1)

        expect(group.users).to include(user)
      end

      it "for event pledge:update" do
        pledge_data = add_pledge
        pledge = pledge_data["data"]
        pledge["attributes"]["amount_cents"] = 987
        patron_id = pledge["relationships"]["patron"]["data"]["id"]
        pledge_data = JSON.pretty_generate(pledge_data)

        expect(PatreonPatron.find_by(patreon_id: patron_id).amount_cents).to eq(250)
        post_request(pledge_data, "update")
        expect(PatreonPatron.find_by(patreon_id: patron_id).amount_cents).to eq(987)
      end

      it "for event pledge:delete" do
        pledge_data = add_pledge
        patron_id = pledge_data["data"]["relationships"]["patron"]["data"]["id"]

        expect(PatreonPatron.find_by(patreon_id: patron_id)).to be_present

        expect { post_request(body, "delete") }.to change { PatreonPatron.count }.by(-1)

        expect(PatreonPatron.find_by(patreon_id: patron_id)).to be_nil
      end
    end
  end
end
