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

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns a valid error when action_name is invalid" do
        post "/admin/logs/screened_ip_addresses.json",
             params: {
               ip_address: "1.2.3.4",
               action_name: "invalid_value",
             }

        expect(response.status).to eq(400)
      end

      it "allows creating an allow_admin screened ip address" do
        post "/admin/logs/screened_ip_addresses.json",
             params: {
               ip_address: "203.0.113.0/24",
               action_name: "allow_admin",
             }

        expect(response.status).to eq(200)
        expect(
          ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:allow_admin]).count,
        ).to eq(1)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents creating an allow_admin screened ip address" do
        post "/admin/logs/screened_ip_addresses.json",
             params: {
               ip_address: "203.0.113.0/24",
               action_name: "allow_admin",
             }

        expect(response.status).to eq(403)
        expect(
          ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:allow_admin]).count,
        ).to eq(0)
      end

      it "allows creating a block screened ip address" do
        post "/admin/logs/screened_ip_addresses.json",
             params: {
               ip_address: "203.0.113.0/24",
               action_name: "block",
             }

        expect(response.status).to eq(200)
      end
    end
  end

  describe "#update" do
    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents updating a screened ip address to allow_admin" do
        screened_ip = Fabricate(:screened_ip_address, ip_address: "100.0.0.1", action_name: "block")

        put "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json",
            params: {
              ip_address: "100.0.0.1",
              action_name: "allow_admin",
            }

        expect(response.status).to eq(403)
        expect(screened_ip.reload.action_type).to eq(ScreenedIpAddress.actions[:block])
      end

      it "prevents changing an allow_admin screened ip address to block" do
        screened_ip =
          Fabricate(:screened_ip_address, ip_address: "100.0.0.8", action_name: "allow_admin")

        put "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json",
            params: {
              ip_address: "100.0.0.8",
              action_name: "block",
            }

        expect(response.status).to eq(403)
        expect(screened_ip.reload.action_type).to eq(ScreenedIpAddress.actions[:allow_admin])
      end

      it "allows updating a block screened ip address" do
        screened_ip = Fabricate(:screened_ip_address, ip_address: "100.0.0.9", action_name: "block")

        put "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json",
            params: {
              ip_address: "100.0.0.10",
              action_name: "block",
            }

        expect(response.status).to eq(200)
        expect(screened_ip.reload.ip_address.to_s).to eq("100.0.0.10")
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "allows updating a screened ip address to allow_admin" do
        screened_ip = Fabricate(:screened_ip_address, ip_address: "100.0.0.1", action_name: "block")

        put "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json",
            params: {
              ip_address: "100.0.0.1",
              action_name: "allow_admin",
            }

        expect(response.status).to eq(200)
        expect(screened_ip.reload.action_type).to eq(ScreenedIpAddress.actions[:allow_admin])
      end
    end
  end

  describe "#destroy" do
    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "prevents deleting an allow_admin screened ip address" do
        screened_ip =
          Fabricate(:screened_ip_address, ip_address: "100.0.0.5", action_name: "allow_admin")

        delete "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json"

        expect(response.status).to eq(403)
        expect(ScreenedIpAddress.find_by(id: screened_ip.id)).to be_present
      end

      it "allows deleting a block screened ip address" do
        screened_ip = Fabricate(:screened_ip_address, ip_address: "100.0.0.6", action_name: "block")

        delete "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json"

        expect(response.status).to eq(200)
        expect(ScreenedIpAddress.find_by(id: screened_ip.id)).to be_nil
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "allows deleting an allow_admin screened ip address" do
        screened_ip =
          Fabricate(:screened_ip_address, ip_address: "100.0.0.7", action_name: "allow_admin")

        delete "/admin/logs/screened_ip_addresses/#{screened_ip.id}.json"

        expect(response.status).to eq(200)
        expect(ScreenedIpAddress.find_by(id: screened_ip.id)).to be_nil
      end
    end
  end
end
