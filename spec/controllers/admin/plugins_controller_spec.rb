require 'rails_helper'

describe Admin::PluginsController do

  it "is a subclass of AdminController" do
    expect(Admin::PluginsController < Admin::AdminController).to eq(true)
  end

  context "while logged in as an admin" do
    let!(:admin) { log_in(:admin) }

    it 'should return JSON' do
      xhr :get, :index
      expect(response).to be_success
      expect(::JSON.parse(response.body).has_key?('plugins')).to eq(true)
    end
  end

end

