# frozen_string_literal: true

describe Patreon::PatreonAdminController do
  describe "#list" do
    let(:group1) { Fabricate(:group) }
    let(:group2) { Fabricate(:group) }
    let(:admin) { Fabricate(:admin) }
    let(:filters) { { group1.id.to_s => ["0"], group2.id.to_s => ["208"], "777" => ["888"] } }
    let(:rewards) { { "1": { sample: "reward" }, "2": { another: "one" } } }

    before do
      sign_in(admin)
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_creator_access_token = "TOKEN"
      SiteSetting.patreon_creator_refresh_token = "TOKEN"
      Patreon.set("filters", filters)
      Patreon.set("rewards", rewards)
    end

    it "displays list of patreon groups" do
      get "/patreon/list.json"

      result = JSON.parse(response.body)
      expect(result["filters"].count).to eq(2)
      expect(result["rewards"].count).to eq(2)
    end

    it "reports that it is unconfigured when the creator tokens are missing" do
      SiteSetting.patreon_creator_access_token = ""

      get "/patreon/list.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("unconfigured" => true)
    end

    it "displays list of rewards" do
      get "/patreon/rewards.json"

      rewards = JSON.parse(response.body)
      expect(rewards.count).to eq(2)
    end

    it "updates existing filter" do
      ids = %w[1 2]

      post "/patreon/list.json", params: { rewards_ids: ids, group_id: group1.id }

      expect(Patreon.get("filters")[group1.id.to_s]).to eq(ids)
    end

    it "deletes an filter" do
      expect { delete "/patreon/list.json", params: { group_id: group1.id } }.to change {
        Patreon.get("filters").count
      }.by(-1)
      expect(Patreon.get("filters")[group1.id.to_s]).to eq(nil)
    end

    it "syncs patreon groups" do
      Patreon::Patron.expects(:sync_groups)
      post "/patreon/sync_groups.json"
    end

    it "enqueues job to sync patrons and groups" do
      expect_enqueued_with(job: :patreon_sync_patrons_to_groups) do
        post "/patreon/update_data.json"
      end

      expect(response.status).to eq(200)
    end
  end
end
