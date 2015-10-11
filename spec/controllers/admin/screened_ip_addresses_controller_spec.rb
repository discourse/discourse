require 'rails_helper'

describe Admin::ScreenedIpAddressesController do

  it "is a subclass of AdminController" do
    expect(Admin::ScreenedIpAddressesController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  describe 'index' do

    it 'filters screened ip addresses' do
      Fabricate(:screened_ip_address, ip_address: "1.2.3.4")
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5")
      Fabricate(:screened_ip_address, ip_address: "1.2.3.6")
      Fabricate(:screened_ip_address, ip_address: "4.5.6.7")

      xhr :get, :index, filter: "4.*"

      expect(response).to be_success

      result = JSON.parse(response.body)
      expect(result.length).to eq(1)
    end

  end

  describe 'roll_up' do

    it "rolls up 1.2.3.* entries" do
      Fabricate(:screened_ip_address, ip_address: "1.2.3.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.6", match_count: 1)

      Fabricate(:screened_ip_address, ip_address: "42.42.42.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "42.42.42.5", match_count: 1)

      StaffActionLogger.any_instance.expects(:log_roll_up)
      SiteSetting.stubs(:min_ban_entries_for_roll_up).returns(3)

      xhr :post, :roll_up
      expect(response).to be_success

      subnet = ScreenedIpAddress.where(ip_address: "1.2.3.0/24").first
      expect(subnet).to be_present
      expect(subnet.match_count).to eq(3)
    end

    it "rolls up 1.2.*.* entries" do
      Fabricate(:screened_ip_address, ip_address: "1.2.3.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.4.6", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.7.8", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.9.1", match_count: 1)

      Fabricate(:screened_ip_address, ip_address: "1.2.42.0/24", match_count: 1)

      StaffActionLogger.any_instance.expects(:log_roll_up)
      SiteSetting.stubs(:min_ban_entries_for_roll_up).returns(5)

      xhr :post, :roll_up
      expect(response).to be_success

      subnet = ScreenedIpAddress.where(ip_address: "1.2.0.0/16").first
      expect(subnet).to be_present
      expect(subnet.match_count).to eq(6)
    end

  end

end
