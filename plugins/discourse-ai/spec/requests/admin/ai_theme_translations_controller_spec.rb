# frozen_string_literal: true

describe DiscourseAi::Admin::AiThemeTranslationsController do
  fab!(:admin)
  fab!(:user)
  fab!(:theme)

  before { enable_current_plugin }

  describe "#create" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "enqueues the localize job with the theme id" do
        expect_enqueued_with(job: :localize_theme_translations, args: { theme_id: theme.id }) do
          post "/admin/plugins/discourse-ai/ai-theme-translations.json",
               params: {
                 theme_id: theme.id,
               }
        end

        expect(response.status).to eq(204)
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
