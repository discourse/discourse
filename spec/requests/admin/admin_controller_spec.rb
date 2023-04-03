# frozen_string_literal: true

RSpec.describe Admin::AdminController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }

  describe "#index" do
    context "when unauthenticated" do
      it "denies access with a 404 response" do
        get "/admin.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when authenticated" do
      context "as an admin" do
        it "permits access with a 200 response" do
          sign_in(admin)
          get "/admin.json"

          expect(response.status).to eq(200)
        end
      end

      context "as a non-admin" do
        it "denies access with a 403 response" do
          sign_in(moderator)
          get "/admin.json"

          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
        end
      end

      context "when user is admin with api key" do
        it "permits access with a 200 response" do
          api_key = Fabricate(:api_key, user: admin)

          get "/admin.json",
              headers: {
                HTTP_API_KEY: api_key.key,
                HTTP_API_USERNAME: admin.username,
              }

          expect(response.status).to eq(200)
        end
      end

      context "when user is a non-admin with api key" do
        it "denies access with a 403 response" do
          api_key = Fabricate(:api_key, user: moderator)

          get "/admin.json",
              headers: {
                HTTP_API_KEY: api_key.key,
                HTTP_API_USERNAME: moderator.username,
              }

          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
        end
      end
    end
  end
end
