# frozen_string_literal: true

RSpec.describe "Data Explorer AI query generation" do
  fab!(:admin)

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  # background job publishes this when generation completes.
  # it's internals, but allows us to test re-enablement of the buttons
  def simulate_finish_generating(query, user)
    MessageBus.publish(
      "/discourse-data-explorer/queries/ai-generation/#{query.id}",
      { status: "complete", sql: "SELECT 1", name: "Test Query", description: "A test" },
      user_ids: [user.id],
    )
  end

  context "when ai queries setting is disabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = false }

    it "does not show the AI description field in the create form" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-new")
      expect(page).to have_no_field("Generate with AI")
    end
  end

  context "when ai queries setting is enabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "shows the AI description field and creates a query with generating state" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-new--ai")

      find(".query-new--ai textarea[name='ai_description']").fill_in(
        with: "show me users who signed up in the last 7 days",
      )

      find(".query-new--ai .form-kit__actions .btn-primary").click

      expect(page).to have_current_path(%r{/admin/plugins/discourse-data-explorer/queries/\d+})
      expect(page).to have_css(".query-ai-generating")
      expect(page).to have_button("Run", disabled: true)
      expect(page).to have_button("Delete", disabled: true)

      simulate_finish_generating(DiscourseDataExplorer::Query.last, admin)

      expect(page).to have_no_css(".query-ai-generating")
      expect(page).to have_button("Run", disabled: false)
      expect(page).to have_button("Delete", disabled: false)
    end
  end
end
