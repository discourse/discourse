# frozen_string_literal: true

describe DiscourseAi::Admin::AiTranslationsController do
  fab!(:admin)
  fab!(:user)

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
  end

  describe "#show" do
    context "when logged in as admin" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = true
        SiteSetting.content_localization_supported_locales = "en|fr|es"
      end

      it "returns translation progress data" do
        Fabricate.times(14, :post, locale: "en")
        Fabricate.times(1, :post, locale: "fr")
        Fabricate.times(4, :post)

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_progress"]).to be_an(Array)
        expect(json["translation_progress"].length).to eq(3)
        expect(json["translation_id"]).to eq(DiscourseAi::Configuration::Module::TRANSLATION_ID)
        expect(json["enabled"]).to be_in([true, false])
        expect(json["total"]).to eq(19)
        expect(json["posts_with_detected_locale"]).to eq(15)

        # Check structure of first locale data
        locale_data = json["translation_progress"].first
        expect(locale_data["locale"]).to eq("en")
        expect(locale_data["total"]).to eq(15)
        expect(locale_data["done"]).to eq(14)
      end

      it "returns empty when no locales are supported" do
        SiteSetting.content_localization_supported_locales = ""

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_progress"]).to eq([])
        expect(json["total"]).to eq(0)
        expect(json["posts_with_detected_locale"]).to eq(0)
      end

      it "correctly indicates if backfill is enabled" do
        SiteSetting.ai_translation_backfill_hourly_rate = 30

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["backfill_enabled"]).to eq(true)

        SiteSetting.ai_translation_backfill_hourly_rate = 0

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["backfill_enabled"]).to eq(false)
      end

      it "correctly indicates if feature is enabled" do
        SiteSetting.ai_translation_backfill_max_age_days = 30

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["enabled"]).to eq(true)

        SiteSetting.ai_translation_backfill_max_age_days = 0

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["enabled"]).to eq(false)
      end
    end

    context "when not logged in as admin" do
      it "returns 404 for anonymous users" do
        get "/admin/plugins/discourse-ai/ai-translations.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        get "/admin/plugins/discourse-ai/ai-translations.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = false
      end

      it "returns 404" do
        get "/admin/plugins/discourse-ai/ai-translations.json"
        expect(response.status).to eq(404)
      end
    end

    context "when AI translation is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = false
      end

      it "still returns data but with enabled flag set to false" do
        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["enabled"]).to eq(false)
      end
    end
  end
end
