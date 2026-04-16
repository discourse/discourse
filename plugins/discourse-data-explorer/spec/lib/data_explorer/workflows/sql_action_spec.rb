# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Workflows::SqlAction do
  fab!(:user)

  describe "#execute" do
    context "with raw operation" do
      it "substitutes named params into the query" do
        result =
          execute_node(
            configuration: {
              "operation" => "raw",
              "query" => "SELECT username FROM users WHERE id = :user_id",
              "params" => [{ "name" => "user_id", "value" => user.id.to_s }],
            },
          )

        expect(result["username"]).to eq(user.username)
      end

      it "raises when no query is provided" do
        expect {
          execute_node(configuration: { "operation" => "raw", "query" => "" })
        }.to raise_error(ArgumentError, "No SQL query provided")
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
          ArgumentError,
          "No query selected",
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
      expect(schema[:query_id][:visible_if]).to eq({ operation: "queries" })
    end

    it "includes query visible only for raw operation" do
      schema = described_class.property_schema
      expect(schema[:query][:visible_if]).to eq({ operation: "raw" })
    end

    it "includes output_fields" do
      schema = described_class.property_schema
      expect(schema).to have_key(:output_fields)
      expect(schema[:output_fields][:type]).to eq(:array)
      expect(schema[:output_fields][:ui][:hidden]).to eq(true)
    end
  end

  describe ".metadata" do
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

      metadata = described_class.metadata
      query_ids = metadata[:queries].map { |q| q[:id] }

      expect(query_ids).to include(query.id)
      expect(query_ids).not_to include(hidden_query.id)

      entry = metadata[:queries].find { |q| q[:id] == query.id }
      expect(entry[:name]).to eq("Test query")
      expect(entry[:params].first[:identifier]).to eq("user_id")
      expect(entry[:params].first[:type]).to eq(:int)
    end
  end
end
