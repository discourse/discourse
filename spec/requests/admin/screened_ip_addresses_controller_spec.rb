# frozen_string_literal: true

RSpec.describe Admin::ScreenedIpAddressesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    shared_examples "screened ip addresses accessible" do
      it "filters screened ip addresses" do
        Fabricate(:screened_ip_address, ip_address: "1.2.3.4")
        Fabricate(:screened_ip_address, ip_address: "1.2.3.5")
        Fabricate(:screened_ip_address, ip_address: "1.2.3.6")
        Fabricate(:screened_ip_address, ip_address: "4.5.6.7")
        Fabricate(:screened_ip_address, ip_address: "5.0.0.0/8")

        get "/admin/logs/screened_ip_addresses.json", params: { filter: "1.2.*" }

        expect(response.status).to eq(200)
        expect(response.parsed_body.map { |record| record["ip_address"] }).to contain_exactly(
          "1.2.3.4",
          "1.2.3.5",
          "1.2.3.6",
        )

        get "/admin/logs/screened_ip_addresses.json", params: { filter: "4.5.6.7" }

        expect(response.status).to eq(200)
        expect(response.parsed_body.map { |record| record["ip_address"] }).to contain_exactly(
          "4.5.6.7",
        )

        get "/admin/logs/screened_ip_addresses.json", params: { filter: "5.0.0.1" }

        expect(response.status).to eq(200)
        expect(response.parsed_body.map { |record| record["ip_address"] }).to contain_exactly(
          "5.0.0.0/8",
        )

        get "/admin/logs/screened_ip_addresses.json", params: { filter: "6.0.0.1" }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_blank
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "screened ip addresses accessible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "screened ip addresses accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/logs/screened_ip_addresses.json", params: { filter: "1.2.*" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
