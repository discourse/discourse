require 'spec_helper'

describe Admin::ScreenedIpAddressesController do

  it "is a subclass of AdminController" do
    (Admin::ScreenedIpAddressesController < Admin::AdminController).should == true
  end

  let!(:user) { log_in(:admin) }

  describe 'index' do

    it 'returns JSON' do
      xhr :get, :index
      response.should be_success
      JSON.parse(response.body).should be_a(Array)
    end

  end

  describe 'roll_up' do

    it "works" do
      SiteSetting.expects(:min_ban_entries_for_roll_up).returns(3)

      Fabricate(:screened_ip_address, ip_address: "1.2.3.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.6", match_count: 1)

      Fabricate(:screened_ip_address, ip_address: "42.42.42.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "42.42.42.5", match_count: 1)

      xhr :post, :roll_up
      response.should be_success

      subnet = ScreenedIpAddress.where(ip_address: "1.2.3.0/24").first
      subnet.should be_present
      subnet.match_count.should == 3
    end

  end

end
