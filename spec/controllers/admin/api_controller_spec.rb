require 'rails_helper'

describe Admin::ApiController do

  it "is a subclass of AdminController" do
    expect(Admin::ApiController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  context '.index' do
    it "succeeds" do
      get :index, format: :json
      expect(response).to be_success
    end
  end

  context '.regenerate_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      put :regenerate_key, params: { id: 1234 }, format: :json
      expect(response).not_to be_success
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      ApiKey.any_instance.expects(:regenerate!)
      put :regenerate_key, params: { id: api_key.id }, format: :json
    end
  end

  context '.revoke_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      delete :revoke_key, params: { id: 1234 }, format: :json
      expect(response).not_to be_success
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      ApiKey.any_instance.expects(:destroy)
      delete :revoke_key, params: { id: api_key.id }, format: :json
    end
  end

  context '.create_master_key' do
    it "creates a record" do
      expect do
        post :create_master_key, format: :json
      end.to change(ApiKey, :count).by(1)
    end
  end

end
