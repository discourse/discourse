# frozen_string_literal: true

RSpec.describe DiscourseSolved::SuperAdminDashboardSupportController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:support_category, :category)

  before do
    SiteSetting.solved_enabled = true
    support_category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    support_category.save!
  end

  describe "#index" do
    it "returns the support section payload for an admin" do
      sign_in(admin)

      get "/admin/plugins/solved/dashboard-support.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.keys).to include(
        "kpis",
        "topic_outcomes",
        "whos_answering",
        "response_time_distribution",
        "category_options",
      )
    end

    it "accepts a category filter" do
      sign_in(admin)

      get "/admin/plugins/solved/dashboard-support.json",
          params: {
            category_id: support_category.id,
          }

      expect(response.status).to eq(200)
    end

    it "is available to moderators" do
      sign_in(moderator)

      get "/admin/plugins/solved/dashboard-support.json"

      expect(response.status).to eq(200)
    end

    it "is not routable for a regular user" do
      sign_in(user)

      get "/admin/plugins/solved/dashboard-support.json"

      expect(response.status).to eq(404)
    end

    it "is not routable for anonymous users" do
      get "/admin/plugins/solved/dashboard-support.json"

      expect(response.status).to eq(404)
    end
  end
end
