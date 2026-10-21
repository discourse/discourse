# frozen_string_literal: true

RSpec.describe "JSON:API queries", type: :request do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, username: "query_author") }
  fab!(:oldest) do
    Fabricate(
      :query,
      name: "Posts of the week",
      description: "Every post written in the last seven days",
      sql: "SELECT id FROM posts LIMIT 1",
      user: author,
      last_run_at: Time.utc(2026, 8, 1),
    )
  end
  fab!(:middle) do
    Fabricate(
      :query,
      name: "Users who never posted",
      description: "Accounts with no post at all",
      sql: "SELECT id FROM users LIMIT 2",
      user: author,
      last_run_at: Time.utc(2026, 8, 2),
    )
  end
  fab!(:newest) do
    Fabricate(
      :query,
      name: "Topics of a category",
      description: "Every topic filed under one category",
      sql: "SELECT id FROM topics LIMIT 3",
      user: author,
      last_run_at: Time.utc(2026, 8, 3),
    )
  end

  fab!(:analysts) { Fabricate(:group, name: "analysts") }

  let(:base) { "http://test.localhost/api/data-explorer" }
  let(:root) { "http://test.localhost/api" }
  let(:query_parameters) { {} }
  let(:user) { admin }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:headers) { { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s } }

  before do
    SiteSetting.data_explorer_enabled = true
    host! Discourse.current_hostname
    sign_in(user)
    [oldest, middle, newest].each { Fabricate(:query_group, query: it, group: analysts) }
  end

  shared_context "with synchronized default queries" do
    let!(:existing_query) do
      Fabricate(:query, id: -1, name: "Old definition", hidden:, last_run_at: 2.days.ago)
    end
    let(:hidden) { false }
    let(:definition) { DiscourseDataExplorer::Queries.default.fetch("-1") }

    before do
      existing_query.groups = [analysts]
      DiscourseDataExplorer::QueryTag.sync!(query: existing_query, names: ["staff"])
      DiscourseDataExplorer::DefaultQuerySync.execute
    end
  end

  shared_examples "a request only for admins" do
    context "when the user is not an admin" do
      fab!(:visitor, :user)

      let(:user) { visitor }

      it { expect(response).to have_http_status(:forbidden) }

      it "sends the reason" do
        expect(parsed_body["errors"].sole).to eq(
          "status" => "403",
          "title" => "Forbidden",
          "detail" => "You are not allowed to make this request.",
        )
      end
    end
  end

  describe "GET /index" do
    let(:path) { "/api/data-explorer/queries" }
    let(:data) do
      [newest, middle, oldest].map do |query|
        {
          "type" => "queries",
          "id" => query.id.to_s,
          "attributes" => {
            "name" => query.name,
            "description" => query.description,
            "sql" => query.sql,
            "paramInfo" => [],
            "isDefault" => false,
            "createdAt" => query.created_at.as_json,
            "lastRunAt" => query.last_run_at.as_json,
            "tags" => ["custom"],
          },
          "links" => {
            "self" => "#{base}/queries/#{query.id}",
          },
        }
      end
    end
    let(:links) do
      {
        "self" => {
          "href" => "#{base}/queries",
          "type" => JsonApiKit::Pagination::Profile::MEDIA_TYPE,
        },
        "prev" => nil,
        "next" => nil,
      }
    end

    context "when queries are custom" do
      before { get(path, headers:, params: query_parameters) }

      it_behaves_like "a request only for admins"

      it "sends the first page of queries" do
        expect(parsed_body).to eq("data" => data, "included" => [], "links" => links)
      end

      context "when the request filters by a word in the name" do
        let(:query_parameters) { { filter: { search: "NEVER POSTED" } } }

        it "sends the queries that match, whatever the case" do
          expect(parsed_body["data"].map { it["attributes"]["name"] }).to eq(
            ["Users who never posted"],
          )
        end
      end

      context "when the request filters by a word in the description" do
        let(:query_parameters) { { filter: { search: "seven days" } } }

        it "sends the queries that match" do
          expect(parsed_body["data"].map { it["attributes"]["name"] }).to eq(["Posts of the week"])
        end
      end

      context "when the filter value holds a wildcard character" do
        let(:query_parameters) { { filter: { search: "%" } } }

        it "reads it as a plain character" do
          expect(parsed_body["data"]).to be_empty
        end
      end

      context "when the request includes the author and the groups" do
        let(:query_parameters) { { include: "user,groups" } }

        it "sends every related record under its own namespace" do
          expect(parsed_body["included"]).to contain_exactly(
            {
              "type" => "users",
              "id" => author.id.to_s,
              "attributes" => {
                "username" => "query_author",
              },
              "links" => {
                "self" => "#{root}/users/#{author.id}",
              },
            },
            {
              "type" => "groups",
              "id" => analysts.id.to_s,
              "attributes" => {
                "name" => "analysts",
              },
              "links" => {
                "self" => "#{root}/groups/#{analysts.id}",
              },
            },
          )
        end
      end
    end

    context "when default queries are synchronized" do
      include_context "with synchronized default queries"

      let(:query_parameters) { super().merge(sort: "name") }
      let(:query_ids) { DiscourseDataExplorer::Query.where(hidden: false).order(:name).pluck(:id) }
      let(:first_page) { JSON.parse(response.body) }
      let(:second_page) { JSON.parse(response.body) }
      let(:first_page_ids) { first_page.fetch("data").map { it["id"].to_i } }
      let(:second_page_ids) { second_page.fetch("data").map { it["id"].to_i } }

      before { get(path, headers:, params: query_parameters) }

      it "paginates default and custom queries together", :aggregate_failures do
        expect(first_page_ids.size).to eq(50)

        get(first_page.fetch("links").fetch("next"), headers:)

        expect(first_page_ids + second_page_ids).to eq(query_ids)
        expect(second_page.dig("links", "next")).to be_nil
      end

      context "when a default query is hidden" do
        let(:hidden) { true }

        it "excludes the query from the list" do
          expect(first_page_ids).not_to include(existing_query.id)
        end
      end
    end
  end

  describe "GET /show" do
    let(:path) { "/api/data-explorer/queries/#{middle.id}" }

    context "when queries are custom" do
      before { get(path, headers:, params: query_parameters) }

      it_behaves_like "a request only for admins"

      it "sends one query" do
        expect(parsed_body).to eq(
          "data" => {
            "type" => "queries",
            "id" => middle.id.to_s,
            "attributes" => {
              "name" => middle.name,
              "description" => middle.description,
              "sql" => middle.sql,
              "paramInfo" => [],
              "isDefault" => false,
              "createdAt" => middle.created_at.as_json,
              "lastRunAt" => middle.last_run_at.as_json,
              "tags" => ["custom"],
            },
            "links" => {
              "self" => "#{base}/queries/#{middle.id}",
            },
          },
          "included" => [],
          "links" => {
            "self" => {
              "href" => "#{base}/queries/#{middle.id}",
              "type" => JsonApiKit::Pagination::Profile::MEDIA_TYPE,
            },
          },
        )
      end

      context "when the query is hidden" do
        fab!(:secret) { Fabricate(:query, name: "Hidden from the listing", hidden: true) }

        let(:path) { "/api/data-explorer/queries/#{secret.id}" }

        it { expect(response).to have_http_status(:not_found) }
      end
    end

    context "when default queries are synchronized" do
      include_context "with synchronized default queries"

      let(:path) { "/api/data-explorer/queries/#{existing_query.id}" }

      before { get(path, headers:, params: query_parameters) }

      it "serves the current default definition" do
        expect(parsed_body.fetch("data")).to include(
          "id" => existing_query.id.to_s,
          "attributes" =>
            a_hash_including(
              "name" => definition.fetch("name"),
              "sql" => definition.fetch("sql"),
              "isDefault" => true,
              "tags" => %w[default users staff],
            ),
        )
      end

      context "when a default query is hidden" do
        let(:hidden) { true }

        it "returns not found for the query" do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
