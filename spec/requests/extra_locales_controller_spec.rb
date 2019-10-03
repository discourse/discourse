# frozen_string_literal: true

require 'rails_helper'

describe ExtraLocalesController do
  context 'show' do

    it "won't work with a weird parameter" do
      get "/extra-locales/-invalid..character!!"
      expect(response.status).to eq(404)
    end

    it "needs a valid bundle" do
      get "/extra-locales/made-up-bundle"
      expect(response.status).to eq(403)
    end

    it "requires staff access" do
      get "/extra-locales/admin"
      expect(response.status).to eq(403)

      get "/extra-locales/wizard"
      expect(response.status).to eq(403)
    end

    context "logged in as a moderator" do

      let(:moderator) { Fabricate(:moderator) }
      before { sign_in(moderator) }

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

  describe ".bundle_js_hash" do
    it "doesn't call bundle_js more than once for the same locale and bundle" do
      I18n.locale = :de
      ExtraLocalesController.expects(:bundle_js).with("admin").returns("admin_js DE").once
      expected_hash_de = Digest::MD5.hexdigest("admin_js DE")

      expect(ExtraLocalesController.bundle_js_hash("admin")).to eq(expected_hash_de)
      expect(ExtraLocalesController.bundle_js_hash("admin")).to eq(expected_hash_de)

      I18n.locale = :fr
      ExtraLocalesController.expects(:bundle_js).with("admin").returns("admin_js FR").once
      expected_hash_fr = Digest::MD5.hexdigest("admin_js FR")

      expect(ExtraLocalesController.bundle_js_hash("admin")).to eq(expected_hash_fr)
      expect(ExtraLocalesController.bundle_js_hash("admin")).to eq(expected_hash_fr)

      I18n.locale = :de
      expect(ExtraLocalesController.bundle_js_hash("admin")).to eq(expected_hash_de)

      ExtraLocalesController.expects(:bundle_js).with("wizard").returns("wizard_js DE").once
      expected_hash_de = Digest::MD5.hexdigest("wizard_js DE")

      expect(ExtraLocalesController.bundle_js_hash("wizard")).to eq(expected_hash_de)
      expect(ExtraLocalesController.bundle_js_hash("wizard")).to eq(expected_hash_de)
    end
  end
end
