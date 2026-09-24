# frozen_string_literal: true

describe DiscourseAi::Admin::AiThemeTranslationsController do
  fab!(:admin)
  fab!(:user)
  fab!(:theme)

  before do
    enable_current_plugin
    SiteSetting.content_localization_supported_locales = "en|fr|es"
  end

  describe "#create" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "enqueues the localize job with the theme id and defaults source_locale to en" do
        expect_enqueued_with(
          job: :localize_theme_translations,
          args: {
            theme_id: theme.id,
            source_locale: "en",
            target_locales: %w[fr es],
            override_existing: false,
          },
        ) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
               }
        end

        expect(response.status).to eq(204)
      end

      it "passes a valid locale through as source_locale" do
        expect_enqueued_with(
          job: :localize_theme_translations,
          args: {
            theme_id: theme.id,
            source_locale: "fr",
            target_locales: %w[en es],
            override_existing: false,
          },
        ) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
                 locale: "fr",
               }
        end
      end

      it "defaults to en when locale is invalid" do
        expect_enqueued_with(
          job: :localize_theme_translations,
          args: {
            theme_id: theme.id,
            source_locale: "en",
            target_locales: %w[fr es],
            override_existing: false,
          },
        ) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
                 locale: "not-a-locale",
               }
        end
      end

      it "queues only confirmed supported targets and explicitly requested replacement" do
        expect_enqueued_with(
          job: :localize_theme_translations,
          args: {
            theme_id: theme.id,
            source_locale: "en",
            target_locales: ["fr"],
            override_existing: true,
          },
        ) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
                 locale: "en",
                 target_locales: %w[en fr ja],
                 override_existing: "true",
               }
        end
        expect(response.status).to eq(204)
      end

      it "does not treat the string false as permission to replace translations" do
        expect_enqueued_with(
          job: :localize_theme_translations,
          args: {
            theme_id: theme.id,
            source_locale: "en",
            target_locales: %w[fr es],
            override_existing: false,
          },
        ) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
                 override_existing: "false",
               }
        end
      end

      it "returns 404 when the theme does not exist" do
        post "/admin/plugins/discourse-ai/ai-theme-translations.json", params: { theme_id: -999 }
        expect(response.status).to eq(404)
      end
    end

    context "when not admin" do
      it "returns 404 for anonymous users" do
        post "/admin/plugins/discourse-ai/ai-theme-translations.json",
             params: {
               theme_id: theme.id,
             }
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        post "/admin/plugins/discourse-ai/ai-theme-translations.json",
             params: {
               theme_id: theme.id,
             }
        expect(response.status).to eq(404)
      end
    end

    context "when the plugin is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = false
      end

      it "returns 404" do
        post "/admin/plugins/discourse-ai/ai-theme-translations.json",
             params: {
               theme_id: theme.id,
             }
        expect(response.status).to eq(404)
      end
    end
  end
end
