require 'rails_helper'

describe Admin::ApiController do

  it "is a subclass of AdminController" do
    expect(Admin::ApiController < Admin::AdminController).to eq(true)
  end

  let(:admin) { Fabricate(:admin) }
  before do
    sign_in(admin)
  end

  describe '#index' do
    it "succeeds" do
      get "/admin/api/keys.json"
      expect(response.status).to eq(200)
    end
  end

  describe '#regenerate_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      put "/admin/api/key.json", params: { id: 1234 }
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      prev_value = api_key.key
      put "/admin/api/key.json", params: { id: api_key.id }
      expect(response.status).to eq(200)

      api_key.reload
      expect(api_key.key).not_to eq(prev_value)
      expect(api_key.created_by.id).to eq(admin.id)
    end
  end

  describe '#revoke_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      delete "/admin/api/key.json", params: { id: 1234 }
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      delete "/admin/api/key.json", params: { id: api_key.id }
      expect(response.status).to eq(200)
      expect(ApiKey.where(key: api_key.key).count).to eq(0)
    end
  end

  describe '#create_master_key' do
    it "creates a record" do
      expect do
        post "/admin/api/key.json"
      end.to change(ApiKey, :count).by(1)
      expect(response.status).to eq(200)
    end
  end
end
