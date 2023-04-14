# frozen_string_literal: true

RSpec.describe Admin::PluginsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  describe "#index" do
    context "while logged in as an admin" do
      before { sign_in(admin) }

      it "returns plugins" do
        get "/admin/plugins.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.has_key?("plugins")).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns plugins" do
        get "/admin/plugins.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.has_key?("plugins")).to eq(true)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/plugins.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
