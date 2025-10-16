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
        SiteSetting.ai_translation_backfill_max_age_days = 30
        SiteSetting.ai_translation_backfill_limit_to_public_content = false

        english_posts = Fabricate.times(14, :post, locale: "en")
        french_post = Fabricate(:post, locale: "fr")
        Fabricate.times(4, :post)

        PostLocalization.create!(
          post: french_post,
          locale: "en",
          raw: "Translated to English",
          cooked: "<p>Translated to English</p>",
          post_version: french_post.version,
          localizer_user_id: admin.id,
        )

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
        # en is the default locale, so total should only be posts requiring translation (1 French post)
        expect(locale_data["total"]).to eq(1)
        # done should be 1 because we translated the French post to English
        expect(locale_data["done"]).to eq(1)
      end

      it "shows only posts requiring translation for all locales (consistent behavior)" do
        SiteSetting.ai_translation_backfill_max_age_days = 30
        SiteSetting.ai_translation_backfill_limit_to_public_content = false
        SiteSetting.default_locale = "en"

        english_posts = Fabricate.times(100, :post, locale: "en")
        french_posts = Fabricate.times(10, :post, locale: "fr")
        spanish_posts = Fabricate.times(5, :post, locale: "es")

        french_posts
          .take(8)
          .each do |post|
            PostLocalization.create!(
              post: post,
              locale: "en",
              raw: "Translated to English",
              cooked: "<p>Translated to English</p>",
              post_version: post.version,
              localizer_user_id: admin.id,
            )
          end
        spanish_posts
          .take(3)
          .each do |post|
            PostLocalization.create!(
              post: post,
              locale: "en",
              raw: "Translated to English",
              cooked: "<p>Translated to English</p>",
              post_version: post.version,
              localizer_user_id: admin.id,
            )
          end

        english_posts
          .take(50)
          .each do |post|
            PostLocalization.create!(
              post: post,
              locale: "fr",
              raw: "Translated to French",
              cooked: "<p>Translated to French</p>",
              post_version: post.version,
              localizer_user_id: admin.id,
            )
          end

        english_posts
          .drop(50)
          .take(30)
          .each do |post|
            PostLocalization.create!(
              post: post,
              locale: "es",
              raw: "Translated to Spanish",
              cooked: "<p>Translated to Spanish</p>",
              post_version: post.version,
              localizer_user_id: admin.id,
            )
          end

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        progress = json["translation_progress"]

        en_data = progress.find { |p| p["locale"] == "en" }
        fr_data = progress.find { |p| p["locale"] == "fr" }
        es_data = progress.find { |p| p["locale"] == "es" }

        # 15 non-English posts (10 fr + 5 es)
        expect(en_data["total"]).to eq(15)
        # 11 translated to English (8 fr + 3 es)
        expect(en_data["done"]).to eq(11)

        # 105 non-French posts (100 en + 5 es)
        expect(fr_data["total"]).to eq(105)
        # 50 translated to French
        expect(fr_data["done"]).to eq(50)

        # 110 non-Spanish posts (100 en + 10 fr)
        expect(es_data["total"]).to eq(110)
        # 30 translated to Spanish
        expect(es_data["done"]).to eq(30)
      end

      it "returns empty when no locales are supported" do
        SiteSetting.content_localization_supported_locales = ""

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_progress"]).to eq([])
        expect(json["total"]).to eq(0)
        expect(json["posts_with_detected_locale"]).to eq(0)
        expect(json["no_locales_configured"]).to eq(true)
      end

      it "returns translation_enabled field" do
        SiteSetting.ai_translation_backfill_max_age_days = 30

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_enabled"]).to eq(true)

        SiteSetting.ai_translation_enabled = false

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_enabled"]).to eq(false)
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
