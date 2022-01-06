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
      Fabricate(:screened_ip_address, ip_address: "5.0.0.0/8")

      get "/admin/logs/screened_ip_addresses.json", params: { filter: "1.2.*" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(3)

      get "/admin/logs/screened_ip_addresses.json", params: { filter: "4.5.6.7" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(1)

      get "/admin/logs/screened_ip_addresses.json", params: { filter: "5.0.0.1" }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result.length).to eq(1)
    end
  end
end
