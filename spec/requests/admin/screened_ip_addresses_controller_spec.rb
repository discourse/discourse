# frozen_string_literal: true

require 'rails_helper'

describe Admin::ScreenedIpAddressesController do

  it "is a subclass of AdminController" do
    expect(Admin::ScreenedIpAddressesController < Admin::AdminController).to eq(true)
  end

  fab!(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    it 'filters screened ip addresses' do
      Fabricate(:screened_ip_address, ip_address: "1.2.3.4")
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5")
      Fabricate(:screened_ip_address, ip_address: "1.2.3.6")
      Fabricate(:screened_ip_address, ip_address: "4.5.6.7")

      get "/admin/logs/screened_ip_addresses.json", params: { filter: "1.2.*" }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.length).to eq(3)

      get "/admin/logs/screened_ip_addresses.json", params: { filter: "4.5.6.7" }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.length).to eq(1)
    end
  end

  describe '#roll_up' do
    it "rolls up 1.2.3.* entries" do
      Fabricate(:screened_ip_address, ip_address: "1.2.3.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.5", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "1.2.3.6", match_count: 1)

      Fabricate(:screened_ip_address, ip_address: "42.42.42.4", match_count: 1)
      Fabricate(:screened_ip_address, ip_address: "42.42.42.5", match_count: 1)

      SiteSetting.min_ban_entries_for_roll_up = 3

      expect do
        post "/admin/logs/screened_ip_addresses/roll_up.json"
      end.to change { UserHistory.where(action: UserHistory.actions[:roll_up]).count }.by(1)

      expect(response.status).to eq(200)

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

      SiteSetting.min_ban_entries_for_roll_up = 5

      expect do
        post "/admin/logs/screened_ip_addresses/roll_up.json"
      end.to change { UserHistory.where(action: UserHistory.actions[:roll_up]).count }.by(1)

      expect(response.status).to eq(200)

      subnet = ScreenedIpAddress.where(ip_address: "1.2.0.0/16").first
      expect(subnet).to be_present
      expect(subnet.match_count).to eq(6)
    end
  end
end
