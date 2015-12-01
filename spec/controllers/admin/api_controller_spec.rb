require 'rails_helper'

describe Admin::ApiController do

  it "is a subclass of AdminController" do
    expect(Admin::ApiController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  context '.index' do
    it "succeeds" do
      xhr :get, :index
      expect(response).to be_success
    end
  end

  context '.regenerate_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      xhr :put, :regenerate_key, id: 1234
      expect(response).not_to be_success
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      ApiKey.any_instance.expects(:regenerate!)
      xhr :put, :regenerate_key, id: api_key.id
    end
  end

  context '.revoke_key' do
    let(:api_key) { Fabricate(:api_key) }

    it "returns 404 when there is no key" do
      xhr :delete, :revoke_key, id: 1234
      expect(response).not_to be_success
      expect(response.status).to eq(404)
    end

    it "delegates to the api key's `regenerate!` method" do
      ApiKey.any_instance.expects(:destroy)
      xhr :delete, :revoke_key, id: api_key.id
    end
  end

  context '.create_master_key' do
    it "creates a record" do
      expect {
        xhr :post, :create_master_key
      }.to change(ApiKey, :count).by(1)
    end
  end

end
