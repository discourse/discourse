# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::DataTable::FilterResolver do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "contacts",
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
        { "name" => "active", "type" => "boolean" },
      ],
    )
  end

  let(:resolver) { described_class.new(data_table) }

  describe "#resolve" do
    it "returns nil when no filter conditions are present" do
      expect(resolver.resolve({})).to be_nil
      expect(resolver.resolve("filter" => [])).to be_nil
    end

    it "resolves a single equals condition" do
      config = {
        "filter_combinator" => "and",
        "filter" => [
          {
            "leftValue" => "email",
            "operator" => {
              "operation" => "equals",
            },
            "rightValue" => "test@example.com",
          },
        ],
      }

      result = resolver.resolve(config)

      expect(result["type"]).to eq("and")
      expect(result["filters"].length).to eq(1)
      expect(result["filters"].first).to include(
        "columnName" => "email",
        "condition" => "eq",
        "value" => "test@example.com",
      )
    end

    it "resolves empty/notEmpty operators to nil values" do
      config = {
        "filter" => [{ "leftValue" => "email", "operator" => { "operation" => "empty" } }],
      }

      result = resolver.resolve(config)

      expect(result["filters"].first).to include("condition" => "eq", "value" => nil)
    end

    it "resolves boolean operators" do
      config = {
        "filter" => [{ "leftValue" => "active", "operator" => { "operation" => "true" } }],
      }

      result = resolver.resolve(config)

      expect(result["filters"].first).to include("condition" => "eq", "value" => true)
    end

    it "defaults filter combinator to 'and'" do
      config = {
        "filter" => [
          {
            "leftValue" => "email",
            "operator" => {
              "operation" => "equals",
            },
            "rightValue" => "a",
          },
        ],
      }

      expect(resolver.resolve(config)["type"]).to eq("and")
    end

    it "raises for unknown column names" do
      config = {
        "filter" => [
          {
            "leftValue" => "unknown",
            "operator" => {
              "operation" => "equals",
            },
            "rightValue" => "x",
          },
        ],
      }

      expect { resolver.resolve(config) }.to raise_error(ArgumentError, /Unknown column name/)
    end

    it "raises for unsupported operators" do
      config = {
        "filter" => [
          {
            "leftValue" => "email",
            "operator" => {
              "operation" => "regex",
            },
            "rightValue" => ".*",
          },
        ],
      }

      expect { resolver.resolve(config) }.to raise_error(ArgumentError, /Unsupported operator/)
    end
  end

  describe "#resolve_sort_column_name" do
    it "returns nil for blank column name" do
      expect(resolver.resolve_sort_column_name(nil)).to be_nil
      expect(resolver.resolve_sort_column_name("")).to be_nil
    end

    it "returns the column name for a valid name" do
      expect(resolver.resolve_sort_column_name("email")).to eq("email")
    end

    it "raises for unknown column name" do
      expect { resolver.resolve_sort_column_name("unknown") }.to raise_error(
        ArgumentError,
        /Unknown column name/,
      )
    end
  end
end
