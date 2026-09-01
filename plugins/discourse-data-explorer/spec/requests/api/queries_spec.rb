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

  before { [oldest, middle, newest].each { Fabricate(:query_group, query: it, group: analysts) } }

  let(:base) { "http://test.localhost/api/data-explorer" }
  let(:root) { "http://test.localhost/api" }
  let(:query_parameters) { {} }
  let(:user) { admin }
  let(:parsed_body) { JSON.parse(response.body) }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(user)
    get path, params: query_parameters
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
            "param_info" => [],
            "is_default" => false,
            "created_at" => query.created_at.as_json,
            "last_run_at" => query.last_run_at.as_json,
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

  describe "GET /show" do
    let(:path) { "/api/data-explorer/queries/#{middle.id}" }

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
            "param_info" => [],
            "is_default" => false,
            "created_at" => middle.created_at.as_json,
            "last_run_at" => middle.last_run_at.as_json,
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
end
