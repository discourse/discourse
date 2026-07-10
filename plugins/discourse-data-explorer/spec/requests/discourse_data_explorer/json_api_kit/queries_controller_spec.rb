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
          "Discourse-Api-Version" => "2026-07-08",
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

      doc = get_index(include: "user,groups", filter: { q: query.name })
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

      doc = get_index(include: "user.groups", filter: { q: query.name })
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

  describe "#index cursor pagination (JSON:API cursor-pagination profile)" do
    fab!(:second_query) { Fabricate(:query, user: author, hidden: false) }
    fab!(:third_query) { Fabricate(:query, user: author, hidden: false) }

    let(:profile_uri) { "https://jsonapi.org/profiles/ethanresnick/cursor-pagination" }
    let(:parsed_document) { JSON.parse(response.body) }
    let(:data_ids) { parsed_document["data"].map { it["id"].to_i } }

    before { sign_in(admin) }

    def get_page(page: {}, sort: nil)
      request_params = { page: }
      request_params[:sort] = sort if sort
      get "/data-explorer/api/queries",
          params: request_params,
          headers: {
            "Accept" => "application/vnd.api+json;profile=\"#{profile_uri}\"",
            "Discourse-Api-Version" => "2026-07-08",
          }
      JSON.parse(response.body)
    end

    it "serves the first page with profile links and item cursors" do
      get_page(page: { size: 2 })

      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to include(profile_uri)
      expect(data_ids).to eq([third_query.id, second_query.id])
      expect(parsed_document["links"]).to have_key("prev")
      expect(parsed_document["links"]["prev"]).to be_nil
      expect(parsed_document["links"]["next"]).to include("page")
      expect(parsed_document["data"].map { it.dig("meta", "page", "cursor") }).to all(be_present)
    end

    it "walks forward and back through cursors" do
      first_page = get_page(page: { size: 2 })
      after = first_page["data"].last.dig("meta", "page", "cursor")

      second_page = get_page(page: { size: 2, after: })
      expect(second_page["data"].map { it["id"].to_i }).to eq([query.id])
      expect(second_page["links"]["next"]).to be_nil

      before_cursor = second_page["data"].first.dig("meta", "page", "cursor")
      back_page = get_page(page: { size: 2, before: before_cursor })
      expect(back_page["data"].map { it["id"].to_i }).to eq(
        first_page["data"].map { it["id"].to_i },
      )
    end

    it "rejects an oversized page with the typed error" do
      doc = get_page(page: { size: 101 })

      expect(response.status).to eq(400)
      expect(doc["errors"].first.dig("links", "type")).to eq("#{profile_uri}/max-size-exceeded")
      expect(doc["errors"].first.dig("meta", "page", "maxSize")).to eq(100)
      expect(doc["errors"].first.dig("source", "parameter")).to eq("page[size]")
    end

    it "rejects a non-positive size" do
      doc = get_page(page: { size: 0 })

      expect(response.status).to eq(400)
      expect(doc["errors"].first.dig("source", "parameter")).to eq("page[size]")
    end

    it "rejects a malformed cursor" do
      doc = get_page(page: { after: "not-a-cursor!!" })

      expect(response.status).to eq(400)
      expect(doc["errors"].first.dig("source", "parameter")).to eq("page[after]")
    end

    it "rejects range requests with the typed error" do
      first_page = get_page(page: { size: 2 })
      cursor = first_page["data"].first.dig("meta", "page", "cursor")

      doc = get_page(page: { after: cursor, before: cursor })

      expect(response.status).to eq(400)
      expect(doc["errors"].first.dig("links", "type")).to eq(
        "#{profile_uri}/range-pagination-not-supported",
      )
    end

    it "walks a derived-sorted listing through cursors" do
      query.update!(name: "Zulu")
      second_query.update!(name: "Beta")
      third_query.update!(name: "Alpha")

      first_page = get_page(page: { size: 2 }, sort: "name")
      expect(first_page["data"].map { it["id"].to_i }).to eq([third_query.id, second_query.id])

      after = first_page["data"].last.dig("meta", "page", "cursor")
      second_page = get_page(page: { size: 2, after: }, sort: "name")
      expect(second_page["data"].map { it["id"].to_i }).to eq([query.id])
      expect(second_page["links"]["next"]).to be_nil
    end

    it "rejects a virtual sort with the typed error" do
      doc = get_page(page: { size: 2 }, sort: "user.username")

      expect(response.status).to eq(400)
      expect(doc["errors"].first.dig("links", "type")).to eq("#{profile_uri}/unsupported-sort")
      expect(doc["errors"].first.dig("source", "parameter")).to eq("sort")
    end

    it "rejects offset pagination" do
      doc = get_page(page: { number: 2 })

      expect(response.status).to eq(400)
      expect(doc["errors"].first["detail"]).to include("page[number]")
    end
  end
end
