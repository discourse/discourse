# frozen_string_literal: true

RSpec.describe Admin::ScreenedUrlsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }
  fab!(:screened_url) { Fabricate(:screened_url) }

  describe "#index" do
    shared_examples "screened urls accessible" do
      it "returns screened urls" do
        get "/admin/logs/screened_urls.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json.size).to eq(1)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "screened urls accessible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "screened urls accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/logs/screened_urls.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
