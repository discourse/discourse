# frozen_string_literal: true

RSpec.describe DiscourseAi::SuperAdmin::SuperAdminDashboardHighlightsController do
  fab!(:admin)
  fab!(:user)

  before { enable_current_plugin }

  describe "#show" do
    context "when the feature is enabled" do
      before do
        assign_fake_provider_to(:ai_default_llm_model)
        SiteSetting.ai_admin_dashboard_enabled = true
        agent =
          AiAgent.find_by(id: -38) ||
            Fabricate(
              :ai_agent,
              id: -38,
              name: "Admin Dashboard Highlights #{SecureRandom.hex(4)}",
              allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
              system: true,
            )
        agent.update!(enabled: true)
        allow(DiscourseAi::AdminDashboard::HighlightGenerator).to receive(:generate).and_return(
          "Your community is thriving.",
        )
      end

      it "returns the highlight for an admin" do
        sign_in(admin)

        get "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
            params: {
              period: "last_30_days",
              start_date: "2026-05-01",
              end_date: "2026-06-01",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["highlight"]).to eq("Your community is thriving.")
      end

      it "passes the requested period and dates through to the generator" do
        sign_in(admin)

        get "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
            params: {
              period: "last_7_days",
              start_date: "2026-06-01",
              end_date: "2026-06-08",
            }

        expect(DiscourseAi::AdminDashboard::HighlightGenerator).to have_received(:generate).with(
          start_date: "2026-06-01",
          end_date: "2026-06-08",
          period: "last_7_days",
        )
      end

      it "is not accessible to non-admins" do
        sign_in(user)

        get "/admin/plugins/discourse-ai/admin-dashboard-highlights.json"

        expect(response.status).to eq(404)
      end
    end

    it "returns 404 when admin dashboard AI features are disabled" do
      SiteSetting.ai_admin_dashboard_enabled = false
      sign_in(admin)

      get "/admin/plugins/discourse-ai/admin-dashboard-highlights.json"

      expect(response.status).to eq(404)
    end

    it "returns 404 when the admin dashboard highlights agent is disabled" do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_admin_dashboard_enabled = true
      AiAgent.where(id: -38).delete_all
      Fabricate(:ai_agent, id: -38, enabled: false)
      sign_in(admin)

      get "/admin/plugins/discourse-ai/admin-dashboard-highlights.json"

      expect(response.status).to eq(404)
    end
  end
end
