# frozen_string_literal: true

# The `deprecate` keyword's runtime half (docs/versioning-design.md §3):
# advisory and reversible — every caller of a deprecated action receives the
# standard RFC 9745 `Deprecation` header (the deprecation date as an epoch)
# plus a `Link rel="deprecation"` to human documentation. No behavior changes.
RSpec.describe "JSON:API Kit endpoint deprecation" do
  fab!(:admin)

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  def get_queries
    get "/data-explorer/api/queries",
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => "2026-07-08",
        }
  end

  context "when the action is deprecated" do
    around do |example|
      DiscourseDataExplorer::JsonApiKit::QueryResource.deprecate(
        :index,
        on: "2026-07-01",
        link: "https://example.com/deprecations/queries",
      )
      example.run
    ensure
      DiscourseDataExplorer::JsonApiKit::QueryResource.deprecated_actions.delete(:index)
    end

    before { get_queries }

    it "announces the deprecation date" do
      expect(response.headers["Deprecation"]).to eq("@#{Time.utc(2026, 7, 1).to_i}")
    end

    it "links the deprecation documentation" do
      expect(response.headers["Link"]).to eq(
        "<https://example.com/deprecations/queries>; rel=\"deprecation\"",
      )
    end

    it "still serves the request" do
      expect(response.status).to eq(200)
    end
  end

  context "when the action is not deprecated" do
    before { get_queries }

    it "sends no deprecation header" do
      expect(response.headers).not_to have_key("Deprecation")
    end
  end
end
