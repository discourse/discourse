# frozen_string_literal: true

require 'rails_helper'

describe Admin::ApiController do

  it "is a subclass of AdminController" do
    expect(Admin::ApiController < Admin::AdminController).to eq(true)
  end

  fab!(:admin) { Fabricate(:admin) }

  fab!(:key1, refind: false) { Fabricate(:api_key, description: "my key") }
  fab!(:key2, refind: false) { Fabricate(:api_key, user: admin) }

  context "as an admin" do
    before do
      sign_in(admin)
    end

    describe '#index' do
      it "succeeds" do
        get "/admin/api/keys.json"
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["keys"].length).to eq(2)
      end
    end

    describe '#show' do
      it "succeeds" do
        get "/admin/api/keys/#{key1.id}.json"
        expect(response.status).to eq(200)
        data = JSON.parse(response.body)["key"]
        expect(data["id"]).to eq(key1.id)
        expect(data["key"]).to eq(nil)
        expect(data["truncated_key"]).to eq(key1.key[0..3])
        expect(data["description"]).to eq("my key")
      end
    end

    describe '#update' do
      it "allows updating the description" do
        original_key = key1.key

        put "/admin/api/keys/#{key1.id}.json", params: {
          key: {
            description: "my new description",
            key: "overridekey"
          }
        }
        expect(response.status).to eq(200)

        key1.reload
        expect(key1.description).to eq("my new description")
        expect(key1.key).to eq(original_key)

        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_update])
        expect(UserHistory.last.subject).to eq(key1.truncated_key)
      end

      it "returns 400 for invalid payloads" do
        put "/admin/api/keys/#{key1.id}.json", params: {
          key: "string not a hash"
        }
        expect(response.status).to eq(400)

        put "/admin/api/keys/#{key1.id}.json", params: {}
        expect(response.status).to eq(400)
      end
    end

    describe "#destroy" do
      it "works" do
        expect(ApiKey.exists?(key1.id)).to eq(true)

        delete "/admin/api/keys/#{key1.id}.json"

        expect(response.status).to eq(200)
        expect(ApiKey.exists?(key1.id)).to eq(false)

        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_destroy])
        expect(UserHistory.last.subject).to eq(key1.truncated_key)
      end
    end

    describe "#create" do
      it "can create a master key" do
        post "/admin/api/keys.json", params: {
          key: {
            description: "master key description"
          }
        }
        expect(response.status).to eq(200)

        data = JSON.parse(response.body)

        expect(data['key']['description']).to eq("master key description")
        expect(data['key']['user']).to eq(nil)
        expect(data['key']['key']).to_not eq(nil)
        expect(data['key']['last_used_at']).to eq(nil)

        key = ApiKey.find(data['key']['id'])
        expect(key.description).to eq("master key description")
        expect(key.user).to eq(nil)

        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_create])
        expect(UserHistory.last.subject).to eq(key.truncated_key)
      end

      it "can create a user-specific key" do
        user = Fabricate(:user)
        post "/admin/api/keys.json", params: {
          key: {
            description: "restricted key description",
            username: user.username
          }
        }
        expect(response.status).to eq(200)

        data = JSON.parse(response.body)

        expect(data['key']['description']).to eq("restricted key description")
        expect(data['key']['user']['username']).to eq(user.username)
        expect(data['key']['key']).to_not eq(nil)
        expect(data['key']['last_used_at']).to eq(nil)

        key = ApiKey.find(data['key']['id'])
        expect(key.description).to eq("restricted key description")
        expect(key.user.id).to eq(user.id)

        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_create])
        expect(UserHistory.last.subject).to eq(key.truncated_key)
      end
    end

    describe "#revoke and #undo_revoke" do
      it "works correctly" do
        post "/admin/api/keys/#{key1.id}/revoke.json"
        expect(response.status).to eq 200

        key1.reload
        expect(key1.revoked_at).to_not eq(nil)
        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_update])
        expect(UserHistory.last.subject).to eq(key1.truncated_key)
        expect(UserHistory.last.details).to eq(I18n.t("staff_action_logs.api_key.revoked"))

        post "/admin/api/keys/#{key1.id}/undo-revoke.json"
        expect(response.status).to eq 200

        key1.reload
        expect(key1.revoked_at).to eq(nil)
        expect(UserHistory.last.action).to eq(UserHistory.actions[:api_key_update])
        expect(UserHistory.last.subject).to eq(key1.truncated_key)
        expect(UserHistory.last.details).to eq(I18n.t("staff_action_logs.api_key.restored"))
      end
    end
  end

  context "as a moderator" do
    before do
      sign_in(Fabricate(:moderator))
    end

    it "doesn't allow access" do
      get "/admin/api/keys.json"
      expect(response.status).to eq(404)

      get "/admin/api/key/#{key1.id}.json"
      expect(response.status).to eq(404)

      post "/admin/api/keys.json", params: {
        key: {
          description: "master key description"
        }
      }
      expect(response.status).to eq(404)

      expect(ApiKey.count).to eq(2)
    end
  end
end
