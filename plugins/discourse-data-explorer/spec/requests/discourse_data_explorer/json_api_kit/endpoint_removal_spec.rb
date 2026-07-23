# frozen_string_literal: true

# Executable half of the endpoint-removal design (docs/versioning-design.md §3):
# "removal" is a timeline fact gated by one comparison after version resolution
# — routes never change. Pins from before the removal keep being served (with
# the RFC 9745 warning carrying the removal date); newer pins get a teaching
# 404 naming the replacement's real path (derived via Rails routing).
RSpec.describe "JSON:API Kit endpoint removal" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, user: admin, hidden: false) }

  let(:parsed_document) { JSON.parse(response.body) }
  let(:removal_change) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-07-08"
      description "The single-query endpoint is removed."

      removed_endpoint controller: "discourse_data_explorer/json_api_kit/queries",
                       action: :show,
                       replacement: {
                         controller: "discourse_data_explorer/json_api_kit/queries",
                         action: :index,
                       }
    end
  end

  around do |example|
    DiscourseDataExplorer::JsonApiKit.api_versions.register(removal_change)
    example.run
  ensure
    DiscourseDataExplorer::JsonApiKit.api_versions.unregister(removal_change)
  end

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  def get_query(version:)
    get "/data-explorer/api/queries/#{query.id}",
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => version,
        }
  end

  context "when pinned before the removal" do
    before { get_query(version: "2026-06-01") }

    it "still serves the endpoint" do
      expect(response.status).to eq(200)
    end

    it "announces the removal date" do
      expect(response.headers["Deprecation"]).to eq("@#{Time.utc(2026, 7, 8).to_i}")
    end
  end

  context "when pinned at the removal" do
    before { get_query(version: "2026-07-08") }

    it "answers a teaching 404" do
      expect(response.status).to eq(404)
    end

    it "teaches the removal and the replacement path" do
      expect(parsed_document["errors"].first["detail"]).to eq(
        "This endpoint was removed as of 2026-07-08. Versions pinned earlier still serve it. " \
          "Replacement: /data-explorer/api/queries.",
      )
    end
  end

  context "with a removal declaring no replacement" do
    let(:removal_change) do
      Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
        version "2026-07-08"
        description "The single-query endpoint is removed."

        removed_endpoint controller: "discourse_data_explorer/json_api_kit/queries", action: :show
      end
    end

    before { get_query(version: "2026-07-08") }

    it "teaches the removal alone" do
      expect(parsed_document["errors"].first["detail"]).to eq(
        "This endpoint was removed as of 2026-07-08. Versions pinned earlier still serve it.",
      )
    end
  end
end
