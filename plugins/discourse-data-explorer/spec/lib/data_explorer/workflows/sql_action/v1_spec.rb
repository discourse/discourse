# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Workflows::SqlAction::V1 do
  fab!(:user)

  describe "#execute" do
    context "with raw operation" do
      it "substitutes named params into the query" do
        result =
          execute_node(
            configuration: {
              "operation" => "raw",
              "query" => "SELECT username FROM users WHERE id = :user_id",
              "params" => {
                "values" => [{ "name" => "user_id", "value" => user.id.to_s }],
              },
            },
          )

        expect(result["username"]).to eq(user.username)
      end

      it "resolves named params against the current input item" do
        result =
          execute_node(
            configuration: {
              "operation" => "raw",
              "query" => "SELECT username FROM users WHERE id = :user_id",
              "params" => {
                "values" => [{ "name" => "user_id", "value" => "={{ $json.user_id }}" }],
              },
            },
            item: {
              "json" => {
                "user_id" => user.id,
              },
            },
          )

        expect(result["username"]).to eq(user.username)
      end

      it "raises when no query is provided" do
        expect {
          execute_node(configuration: { "operation" => "raw", "query" => "" })
        }.to raise_error(DiscourseWorkflows::NodeError, "No SQL query provided.")
      end

      it "emits on the empty port when the query returns no rows" do
        result =
          execute_node_output(
            configuration: {
              "operation" => "raw",
              "query" => "SELECT username FROM users WHERE 1=0",
            },
          )

        rows, empty = result
        expect(rows).to be_empty
        expect(empty.size).to eq(1)
        expect(empty.first).to eq({ "json" => {} })
      end

      it "emits on the main port when the query returns rows" do
        result =
          execute_node_output(
            configuration: {
              "operation" => "raw",
              "query" => "SELECT username FROM users WHERE id = :user_id",
              "params" => {
                "values" => [{ "name" => "user_id", "value" => user.id.to_s }],
              },
            },
          )

        rows, empty = result
        expect(empty).to be_empty
        expect(rows.size).to eq(1)
        expect(rows.first["json"]["username"]).to eq(user.username)
      end
    end

    context "with queries operation" do
      fab!(:data_explorer_query) do
        DiscourseDataExplorer::Query.create!(
          name: "User lookup",
          sql: "-- [params]\n-- int :user_id\nSELECT username FROM users WHERE id = :user_id",
          user_id: Discourse::SYSTEM_USER_ID,
        )
      end

      it "runs a saved query with parameters" do
        result =
          execute_node(
            configuration: {
              "operation" => "queries",
              "query_id" => data_explorer_query.id,
              "query_params" => {
                "user_id" => user.id.to_s,
              },
            },
          )

        expect(result["username"]).to eq(user.username)
      end

      it "runs a saved query without parameters" do
        no_params_query =
          DiscourseDataExplorer::Query.create!(
            name: "All users",
            sql: "SELECT username FROM users ORDER BY id LIMIT 1",
            user_id: Discourse::SYSTEM_USER_ID,
          )

        result =
          execute_node(
            configuration: {
              "operation" => "queries",
              "query_id" => no_params_query.id,
            },
          )

        expect(result["username"]).to be_present
      end

      it "raises when query_id is missing" do
        expect { execute_node(configuration: { "operation" => "queries" }) }.to raise_error(
          DiscourseWorkflows::NodeError,
          "No query selected.",
        )
      end
    end
  end

  describe ".property_schema" do
    it "includes operation field" do
      schema = described_class.property_schema
      expect(schema[:operation][:type]).to eq(:options)
      expect(schema[:operation][:options]).to eq(%w[queries raw])
      expect(schema[:operation][:default]).to eq("queries")
    end

    it "includes query_id visible only for queries operation" do
      schema = described_class.property_schema
      expect(schema[:query_id][:display_options]).to eq(show: { operation: ["queries"] })
    end

    it "includes query visible only for raw operation" do
      schema = described_class.property_schema
      expect(schema[:query][:display_options]).to eq(show: { operation: ["raw"] })
    end
  end

  describe ".outputs" do
    it "declares main and empty output ports" do
      keys = described_class.outputs.map { |port| port[:key].to_s }
      expect(keys).to eq(%w[main empty])
    end
  end

  describe ".load_options_context" do
    it "returns non-hidden query options" do
      query =
        DiscourseDataExplorer::Query.create!(
          name: "Visible query",
          sql: "SELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
        )
      hidden_query =
        DiscourseDataExplorer::Query.create!(
          name: "Hidden query",
          sql: "SELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
          hidden: true,
        )
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "queries",
          node_class: described_class,
        )

      options = described_class.load_options_context(context)
      query_ids = options.map { |option| option[:id] }

      expect(query_ids).to include(query.id)
      expect(query_ids).not_to include(hidden_query.id)
    end

    it "filters query options by the filter term" do
      matching_query =
        DiscourseDataExplorer::Query.create!(
          name: "Needle query",
          sql: "SELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
        )
      other_query =
        DiscourseDataExplorer::Query.create!(
          name: "Haystack query",
          sql: "SELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
        )
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "queries",
          filter: "needle",
          node_class: described_class,
        )

      options = described_class.load_options_context(context)
      query_ids = options.map { |option| option[:id] }

      expect(query_ids).to include(matching_query.id)
      expect(query_ids).not_to include(other_query.id)
    end
  end

  describe ".queries" do
    it "includes non-hidden queries with their params" do
      query =
        DiscourseDataExplorer::Query.create!(
          name: "Test query",
          sql: "-- [params]\n-- int :user_id\nSELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
        )
      hidden_query =
        DiscourseDataExplorer::Query.create!(
          name: "Hidden",
          sql: "SELECT 1",
          user_id: Discourse::SYSTEM_USER_ID,
          hidden: true,
        )

      queries = described_class.queries
      query_ids = queries.map { |q| q[:id] }

      expect(query_ids).to include(query.id)
      expect(query_ids).not_to include(hidden_query.id)

      entry = queries.find { |q| q[:id] == query.id }
      expect(entry[:name]).to eq("Test query")
      expect(entry[:params].first[:identifier]).to eq("user_id")
      expect(entry[:params].first[:type]).to eq(:int)
    end
  end
end
