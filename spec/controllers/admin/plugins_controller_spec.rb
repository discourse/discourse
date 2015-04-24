require 'spec_helper'

describe Admin::PluginsController do

  it "is a subclass of AdminController" do
    expect(Admin::PluginsController < Admin::AdminController).to eq(true)
  end

  context "while logged in as an admin" do
    let!(:admin) { log_in(:admin) }

    it 'should return JSON' do
      xhr :get, :index
      response.should be_success
      ::JSON.parse(response.body).has_key?('plugins').should == true
    end
  end

end

