# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FilterOptionsController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/filter-options/posts.json"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/filter-options/posts" do
    it "returns post filter option info" do
      get "/admin/plugins/discourse-workflows/filter-options/posts.json"

      expect(response).to have_http_status(:ok)
      option_names = response.parsed_body["filter_option_info"].map { |option| option["name"] }

      expect(option_names).to include(
        "category:",
        "keywords:",
        "post_type:",
        "post_type:first",
        "status:open",
        "order:latest",
      )
    end
  end
end
