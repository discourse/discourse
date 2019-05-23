# frozen_string_literal: true

require 'rails_helper'

describe ExtraLocalesController do
  context 'show' do
    it "caches for 24 hours if version is provided and it matches current hash" do
      get "/extra-locales/admin", params: { v: ExtraLocalesController.bundle_js_hash('admin') }
      expect(response.status).to eq(200)
      expect(response.headers["Cache-Control"]).to eq("max-age=86400, public, immutable")
    end

    it "does not cache at all if version is invalid" do
      get "/extra-locales/admin", params: { v: 'a' * 32 }
      expect(response.status).to eq(200)
      expect(response.headers["Cache-Control"]).not_to eq("max-age=86400, public, immutable")
    end

    it "needs a valid bundle" do
      get "/extra-locales/made-up-bundle"
      expect(response.status).to eq(403)
    end

    it "won't work with a weird parameter" do
      get "/extra-locales/-invalid..character!!"
      expect(response.status).to eq(404)
    end

    context "with plugin" do
      before do
        JsLocaleHelper.clear_cache!
        JsLocaleHelper.expects(:plugin_translations)
          .with(any_of("en", "en_US"))
          .returns("admin_js" => {
            "admin" => {
              "site_settings" => {
                "categories" => {
                  "github_badges" => "Github Badges"
                }
              }
            }
          }).at_least_once
      end

      after do
        JsLocaleHelper.clear_cache!
      end

      it "includes plugin translations" do
        get "/extra-locales/admin"

        expect(response.status).to eq(200)
        expect(response.body.include?("github_badges")).to eq(true)
      end
    end
  end
end
