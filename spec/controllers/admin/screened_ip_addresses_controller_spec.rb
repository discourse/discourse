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

    it 'can load multiple pages' do
      ipaddr = IPAddr.new "1.2.3.4"
      # Create 200 to bump off the first page
      200.times do
        Fabricate(:screened_ip_address, ip_address: ipaddr.to_s, match_count: 2).save
        ipaddr = ipaddr.succ
      end
      # Create one to be on the top
      first_record = Fabricate(:screened_ip_address, ip_address: "42.42.42.4", match_count: 3)
      first_record.save
      # Create one to be on the bottom
      last_record = Fabricate(:screened_ip_address, ip_address: "42.42.42.5", match_count: 1)
      last_record.save

      # This should get first_record and 199 of the 200 records
      response1 = xhr :get, :index
      response1.should be_success
      result = JSON.parse(response1.body)
      result.should be_a(Array)
      result.length.should == 200
      result.first["id"].should == first_record.id

      # This should get the last of the 200 and last_record
      response2 = xhr :get, :index, after: "#{result.last["match_count"]},#{result.last["id"]}"
      response2.should be_success
      result2 = JSON.parse(response2.body)
      result2.length.should == 2
      result2[0]["match_count"].should == 2
      IPAddr.new(result2[0]["ip_address"]).succ.should == ipaddr
      result2.last["id"].should == last_record.id

      # No duplicates are returned
      #
      # To fail this test: comment out the length check, and change
      #     where!('id > ?', id)
      # to
      #     where!('id >= ?', id)
      (result & result2).should be_blank
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
      response.should be_success

      subnet = ScreenedIpAddress.where(ip_address: "1.2.3.0/24").first
      subnet.should be_present
      subnet.match_count.should == 3
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
      response.should be_success

      subnet = ScreenedIpAddress.where(ip_address: "1.2.0.0/16").first
      subnet.should be_present
      subnet.match_count.should == 6
    end

  end

end
