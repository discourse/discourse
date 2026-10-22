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
            "automaticTags" => ["custom"],
            "dashboardMountable" => true,
            "dashboardMounted" => false,
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
                "avatarTemplate" => author.avatar_template,
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

    context "when the request filters by tags" do
      fab!(:monthly_query, :query)

      let(:query_parameters) { super().merge(filter: { tag: %w[staff monthly] }) }
      let(:query_ids) { parsed_body.fetch("data").map { it.fetch("id").to_i } }
      let(:second_page) { JSON.parse(response.body) }
      let(:second_page_ids) { second_page.fetch("data").map { it.fetch("id").to_i } }

      before do
        DiscourseDataExplorer::QueryTag.sync!(query: oldest, names: %w[staff monthly])
        DiscourseDataExplorer::QueryTag.sync!(query: newest, names: %w[staff monthly])
        DiscourseDataExplorer::QueryTag.sync!(query: middle, names: %w[staff])
        DiscourseDataExplorer::QueryTag.sync!(query: monthly_query, names: %w[monthly])
        get(path, headers:, params: query_parameters)
      end

      it "returns queries that match every selected tag" do
        expect(query_ids).to contain_exactly(oldest.id, newest.id)
      end

      context "when the request supplies one tag as a string" do
        let(:query_parameters) { super().merge(filter: { tag: "staff" }) }

        it "returns queries with that tag" do
          expect(query_ids).to contain_exactly(oldest.id, middle.id, newest.id)
        end
      end

      context "when tag names contain whitespace, duplicates, or different casing" do
        let(:query_parameters) do
          super().merge(filter: { tag: [" STAFF ", "", "Monthly", "staff"] })
        end

        it "matches the normalized tags" do
          expect(query_ids).to contain_exactly(oldest.id, newest.id)
        end
      end

      context "when a selected tag does not exist" do
        let(:query_parameters) { super().merge(filter: { tag: %w[staff unknown] }) }

        it "returns no queries" do
          expect(query_ids).to be_empty
        end
      end

      context "when the results span multiple pages" do
        let(:query_parameters) { super().merge(page: { size: 1 }) }

        it "preserves every tag in the next page request", :aggregate_failures do
          expect(query_ids).to eq([newest.id])

          get(parsed_body.fetch("links").fetch("next"), headers:)

          expect(second_page_ids).to eq([oldest.id])
          expect(second_page.dig("links", "next")).to be_nil
        end
      end
    end

    context "when queries have dashboard reports" do
      let!(:default_query) { DiscourseDataExplorer::Query.find(-1).tap(&:save!) }
      let(:query_parameters) do
        super().merge(sort: "name", fields: { queries: "name,dashboardMounted" })
      end
      let(:sql_queries) { [] }
      let(:dashboard_queries) { sql_queries.grep(/FROM "admin_dashboard_reports"/) }
      let(:dashboard_status) do
        parsed_body
          .fetch("data")
          .to_h { [it.fetch("id"), it.fetch("attributes").fetch("dashboardMounted")] }
      end
      let(:expected_status) do
        { oldest.id.to_s => true, middle.id.to_s => false, newest.id.to_s => false, "-1" => true }
      end

      before do
        [oldest, default_query].each do |query|
          Fabricate(
            :admin_dashboard_report,
            source: "data_explorer_query",
            identifier: query.id.to_s,
          )
        end
        sql_queries.concat(track_sql_queries { get(path, headers:, params: query_parameters) })
      end

      it "returns dashboard status for default and custom queries" do
        expect(dashboard_status).to eq(expected_status)
      end

      it "loads dashboard reports in one query" do
        expect(dashboard_queries.size).to eq(1)
      end

      context "when the request sorts by the author" do
        let(:query_parameters) { super().merge(sort: "user.username") }

        it "loads dashboard reports in one query", :aggregate_failures do
          expect(dashboard_status).to eq(expected_status)
          expect(dashboard_queries.size).to eq(1)
        end
      end

      context "when the request sorts by nullable run timestamps" do
        let(:query_parameters) { super().merge(sort: "-lastRunAt") }

        it "loads dashboard reports in at most two queries", :aggregate_failures do
          expect(dashboard_status).to eq(expected_status)
          expect(dashboard_queries.size).to be <= 2
        end
      end

      context "when the fieldset omits dashboard status" do
        let(:query_parameters) { super().merge(fields: { queries: "name" }) }
        let(:attribute_names) { parsed_body.fetch("data").map { it.fetch("attributes").keys } }

        it "omits dashboard status without loading reports", :aggregate_failures do
          expect(attribute_names).to all(eq(["name"]))
          expect(dashboard_queries).to be_empty
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

      context "when the request filters by automatic and manual tags" do
        let(:query_parameters) { super().merge(filter: { tag: %w[default staff] }) }

        it "returns the matching default query" do
          expect(first_page_ids).to contain_exactly(existing_query.id)
        end
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
              "automaticTags" => ["custom"],
              "dashboardMountable" => true,
              "dashboardMounted" => false,
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

    context "when a dashboard report has the query's identifier" do
      let(:report_source) { "data_explorer_query" }
      let!(:dashboard_report) do
        Fabricate(:admin_dashboard_report, source: report_source, identifier: middle.id.to_s)
      end

      before { get(path, headers:, params: query_parameters) }

      it "reports the query as mounted" do
        expect(parsed_body.dig("data", "attributes").fetch("dashboardMounted")).to be(true)
      end

      context "when the report belongs to another source" do
        let(:report_source) { "core_report" }

        it "reports the query as unmounted" do
          expect(parsed_body.dig("data", "attributes").fetch("dashboardMounted")).to be(false)
        end
      end
    end

    context "when the query has required parameters" do
      let!(:query) { Fabricate(:query, sql:) }
      let(:sql) { "-- [params]\n-- int :topic_id\nSELECT :topic_id AS value" }
      let(:path) { "/api/data-explorer/queries/#{query.id}" }

      before { get(path, headers:, params: query_parameters) }

      it "reports that the query cannot be mounted" do
        expect(parsed_body.dig("data", "attributes").fetch("dashboardMountable")).to be(false)
      end

      context "when the dashboard supplies the required parameters" do
        let(:sql) do
          "-- [params]\n-- date :start_date\n-- date :end_date\nSELECT :start_date, :end_date"
        end

        it "reports that the query can be mounted" do
          expect(parsed_body.dig("data", "attributes").fetch("dashboardMountable")).to be(true)
        end
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
              "automaticTags" => %w[default users],
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
