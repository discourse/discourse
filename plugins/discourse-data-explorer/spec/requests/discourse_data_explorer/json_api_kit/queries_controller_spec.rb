# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::QueriesController do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:group1, :group)
  fab!(:group2, :group)
  fab!(:query) { Fabricate(:query, user: author, hidden: false) }

  before { SiteSetting.data_explorer_enabled = true }

  def get_index(params)
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
        }
    JSON.parse(response.body)
  end

  describe "#index" do
    before { sign_in(admin) }

    it "omits relationship objects on a bare request (conditional linkage)" do
      doc = get_index(page: { size: 5 })

      expect(response.status).to eq(200)
      expect(doc["data"]).to be_present
      expect(doc).not_to have_key("included")
      expect(doc["data"].map { |resource| resource.key?("relationships") }).to all(be(false))
    end

    it "returns a compound document for a top-level include" do
      Fabricate(:query_group, query: query, group: group1)

      doc = get_index(include: "user,groups", filter: { search: query.name })
      resource = doc["data"].find { |row| row["id"].to_i == query.id }
      included = doc["included"].group_by { |inc| inc["type"] }

      expect(resource.dig("relationships", "user", "data", "id")).to eq(author.id.to_s)
      expect(
        resource.dig("relationships", "groups", "data").map { |link| link["id"].to_i },
      ).to contain_exactly(group1.id)
      expect(included["users"].map { |inc| inc["id"].to_i }).to contain_exactly(author.id)
      expect(included["groups"].map { |inc| inc["id"].to_i }).to contain_exactly(group1.id)
    end

    it "resolves a deep nested include (user.groups) with full linkage" do
      group1.add(author)
      group2.add(author)

      doc = get_index(include: "user.groups", filter: { search: query.name })
      resource = doc["data"].find { |row| row["id"].to_i == query.id }
      user_resource =
        doc["included"].find { |inc| inc["type"] == "users" && inc["id"].to_i == author.id }
      included_group_ids =
        doc["included"].select { |inc| inc["type"] == "groups" }.map { |inc| inc["id"].to_i }

      # primary data links to the intermediate (user), which links to the leaf (groups):
      # a complete relationship chain — the JSON:API full-linkage requirement.
      expect(resource.dig("relationships", "user", "data", "id")).to eq(author.id.to_s)
      expect(
        user_resource.dig("relationships", "groups", "data").map { |link| link["id"].to_i },
      ).to include(group1.id, group2.id)
      expect(included_group_ids).to include(group1.id, group2.id)
    end

    it "rejects an unsupported nested include path with a 400" do
      doc = get_index(include: "user.bogus")

      expect(response.status).to eq(400)
      expect(doc["errors"].first["detail"]).to include("user.bogus")
    end
  end
end
