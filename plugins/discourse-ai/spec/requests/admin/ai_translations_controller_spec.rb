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
      fab!(:selected_category, :category)

      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = true
        SiteSetting.content_localization_supported_locales = "en|fr|es"
        SiteSetting.ai_translation_category_scope = "include"
        SiteSetting.ai_translation_categories = selected_category.id.to_s
      end

      it "returns base configuration data without progress" do
        SiteSetting.ai_translation_backfill_max_age_days = 30
        SiteSetting.ai_translation_backfill_hourly_rate = 100

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["translation_id"]).to eq(DiscourseAi::Configuration::Module::TRANSLATION_ID)
        expect(json["enabled"]).to eq(true)
        expect(json["translation_enabled"]).to eq(true)
        expect(json["hourly_rate"]).to eq(100)
        expect(json["backfill_enabled"]).to be_in([true, false])

        expect(json).not_to have_key("translation_progress")
        expect(json).not_to have_key("total")
        expect(json).not_to have_key("posts_with_detected_locale")
      end

      it "returns no_locales_configured when no locales are supported" do
        SiteSetting.content_localization_supported_locales = ""

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["no_locales_configured"]).to eq(true)
      end

      it "does not include no_locales_configured when locales are set" do
        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json).not_to have_key("no_locales_configured")
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

      it "returns category scope settings" do
        other_category = Fabricate(:category)
        SiteSetting.ai_translation_category_scope = "include"
        SiteSetting.ai_translation_categories = "#{selected_category.id}|#{other_category.id}"

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["category_scope"]).to eq("include")
        expect(response.parsed_body["category_ids"]).to contain_exactly(
          selected_category.id,
          other_category.id,
        )
      end

      it "returns an empty array when no categories are configured" do
        SiteSetting.ai_translation_categories = ""

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["category_ids"]).to eq([])
      end

      it "correctly indicates if feature is enabled" do
        SiteSetting.ai_translation_backfill_max_age_days = 30

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["enabled"]).to eq(true)

        SiteSetting.ai_translation_backfill_max_age_days = 0

        get "/admin/plugins/discourse-ai/ai-translations.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["enabled"]).to eq(true)
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

  describe "#progress" do
    context "when logged in as admin" do
      let(:progress) do
        {
          cached_at: "2026-07-23T09:00:00Z",
          targets: [
            {
              target_type: "post",
              total_count: 474,
              translated_count: 215,
              needs_language_detection_count: 93,
            },
            {
              target_type: "topic",
              total_count: 86,
              translated_count: 51,
              needs_language_detection_count: 12,
            },
            {
              target_type: "category",
              total_count: 18,
              translated_count: 18,
              needs_language_detection_count: 0,
            },
            {
              target_type: "tag",
              total_count: 142,
              translated_count: 64,
              needs_language_detection_count: 7,
            },
          ],
        }
      end

      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = true
        SiteSetting.content_localization_supported_locales = "en|fr|es"
        allow(DiscourseAi::Translation::Progress).to receive(:fetch).and_return(progress)
      end

      it "returns all overview targets from the shared cache" do
        get "/admin/plugins/discourse-ai/ai-translations/progress.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(progress.deep_stringify_keys)
        expect(DiscourseAi::Translation::Progress).to have_received(:fetch)
      end

      it "returns progress when the post backfill age is zero" do
        SiteSetting.ai_translation_backfill_max_age_days = 0

        get "/admin/plugins/discourse-ai/ai-translations/progress.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(progress.deep_stringify_keys)
      end
    end

    context "when not logged in as admin" do
      it "returns 404 for anonymous users" do
        get "/admin/plugins/discourse-ai/ai-translations/progress.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        get "/admin/plugins/discourse-ai/ai-translations/progress.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = false
      end

      it "returns 404" do
        get "/admin/plugins/discourse-ai/ai-translations/progress.json"
        expect(response.status).to eq(404)
      end
    end

    context "when translation is not fully enabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = false
        SiteSetting.content_localization_supported_locales = "en|fr"
      end

      it "returns empty progress" do
        get "/admin/plugins/discourse-ai/ai-translations/progress.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq({ "cached_at" => nil, "targets" => [] })
      end
    end
  end

  describe "#progress_detail" do
    let(:detail) do
      {
        target_type: "post",
        cached_at: "2026-07-23T09:00:00Z",
        locales: [{ locale: "en", translated_count: 215, pending_count: 93, eligible_count: 474 }],
      }
    end

    context "when logged in as admin" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = true
        SiteSetting.content_localization_supported_locales = "en|fr"
        allow(DiscourseAi::Translation::Progress).to receive(:fetch_detail).and_return(detail)
      end

      it "returns cached details for an allowed target" do
        get "/admin/plugins/discourse-ai/ai-translations/progress/post.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(detail.deep_stringify_keys)
        expect(DiscourseAi::Translation::Progress).to have_received(:fetch_detail).with("post")
      end

      it "returns 404 for an unsupported target" do
        get "/admin/plugins/discourse-ai/ai-translations/progress/user.json"

        expect(response.status).to eq(404)
        expect(DiscourseAi::Translation::Progress).not_to have_received(:fetch_detail)
      end
    end

    context "when translation is not fully enabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = true
        SiteSetting.ai_translation_enabled = false
        SiteSetting.content_localization_supported_locales = "en|fr"
      end

      it "returns an empty detail response" do
        get "/admin/plugins/discourse-ai/ai-translations/progress/post.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          { "target_type" => "post", "cached_at" => nil, "locales" => [] },
        )
      end
    end

    context "when not logged in as admin" do
      it "returns 404 for anonymous users" do
        get "/admin/plugins/discourse-ai/ai-translations/progress/post.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        get "/admin/plugins/discourse-ai/ai-translations/progress/post.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
