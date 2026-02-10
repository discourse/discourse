# frozen_string_literal: true

describe Patreon::PatreonAdminController do
  describe "#list" do
    let(:group1) { Fabricate(:group) }
    let(:group2) { Fabricate(:group) }
    let(:admin) { Fabricate(:admin) }
    fab!(:reward1) { Fabricate(:patreon_reward, patreon_id: "1", title: "Reward 1") }
    fab!(:reward2) { Fabricate(:patreon_reward, patreon_id: "2", title: "Reward 2") }
    fab!(:all_patrons_reward) do
      Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
    end

    before do
      sign_in(admin)
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_creator_access_token = "TOKEN"
      SiteSetting.patreon_creator_refresh_token = "TOKEN"
      Fabricate(:patreon_group_reward_filter, group: group1, patreon_reward: all_patrons_reward)
      Fabricate(:patreon_group_reward_filter, group: group2, patreon_reward: reward2)
    end

    it "should display list of patreon groups" do
      get "/patreon/list.json"

      result = JSON.parse(response.body)
      expect(result["filters"].count).to eq(2)
      expect(result["rewards"].count).to eq(3)
    end

    it "should display list of rewards" do
      get "/patreon/rewards.json"

      rewards = JSON.parse(response.body)
      expect(rewards.count).to eq(3)
    end

    it "should update existing filter" do
      ids = %w[1 2]

      post "/patreon/list.json", params: { rewards_ids: ids, group_id: group1.id }

      expect(PatreonGroupRewardFilter.where(group_id: group1.id).count).to eq(2)
    end

    it "should return 404 when editing with non-existent group" do
      post "/patreon/list.json", params: { rewards_ids: ["1"], group_id: 999_999 }

      expect(response.status).to eq(404)
    end

    it "should return 422 when editing without rewards_ids" do
      post "/patreon/list.json", params: { group_id: group1.id }

      expect(response.status).to eq(422)
    end

    it "should return 422 when editing with unknown reward IDs" do
      post "/patreon/list.json", params: { rewards_ids: %w[1 nonexistent], group_id: group1.id }

      expect(response.status).to eq(422)
      expect(response.parsed_body["message"]).to include("nonexistent")
    end

    it "should delete a filter" do
      expect { delete "/patreon/list.json", params: { group_id: group1.id } }.to change {
        PatreonGroupRewardFilter.where(group_id: group1.id).count
      }.by(-1)
      expect(PatreonGroupRewardFilter.where(group_id: group1.id).count).to eq(0)
    end

    it "should return 404 when deleting with non-existent group" do
      delete "/patreon/list.json", params: { group_id: 999_999 }

      expect(response.status).to eq(404)
    end

    it "should sync patreon groups" do
      Patreon::Patron.expects(:sync_groups)
      post "/patreon/sync_groups.json"
      expect(response.status).to eq(200)
    end

    it "should return JSON error when sync_groups raises" do
      Patreon::Patron.stubs(:sync_groups).raises(StandardError.new("connection timeout"))
      post "/patreon/sync_groups.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["message"]).to include("synchronization failed")
    end

    it "should enqueue job to sync patrons and groups" do
      expect_enqueued_with(job: :patreon_sync_patrons_to_groups) do
        post "/patreon/update_data.json"
      end

      expect(response.status).to eq(200)
    end

    it "should include last_sync_at in list response" do
      sync_time = 2.hours.ago
      Fabricate(:patreon_sync_log, synced_at: sync_time)

      get "/patreon/list.json"

      result = JSON.parse(response.body)
      expect(Time.zone.parse(result["last_sync_at"])).to be_within(1.second).of(sync_time)
    end
  end

  describe "#email" do
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_creator_access_token = "TOKEN"
      SiteSetting.patreon_creator_refresh_token = "TOKEN"
    end

    it "returns the patron email for a user" do
      user = Fabricate(:user)
      Fabricate(:patreon_patron, patreon_id: "12345", email: "patron@patreon.com")
      user.custom_fields["patreon_id"] = "12345"
      user.save_custom_fields

      get "/u/#{user.username}/patreon_email.json"

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["email"]).to eq("patron@patreon.com")
    end

    it "returns nil email when user has no patreon_id" do
      user = Fabricate(:user)

      get "/u/#{user.username}/patreon_email.json"

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["email"]).to be_nil
    end
  end
end
