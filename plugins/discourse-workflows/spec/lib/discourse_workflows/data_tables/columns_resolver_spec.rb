# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::ColumnsResolver do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  let(:resolver) { described_class.new(data_table) }

  describe "#resolve" do
    it "resolves hash input keyed by column name" do
      result = resolver.resolve("email" => "test@example.com", "score" => "42")

      expect(result).to eq("email" => "test@example.com", "score" => "42")
    end

    it "resolves array input from the workflow editor" do
      result =
        resolver.resolve(
          [
            { "columnName" => "email", "value" => "test@example.com" },
            { "columnName" => "score", "value" => "42" },
          ],
        )

      expect(result).to eq("email" => "test@example.com", "score" => "42")
    end

    it "returns an empty hash for blank input" do
      expect(resolver.resolve(nil)).to eq({})
    end

    it "raises for unknown column names" do
      expect { resolver.resolve("unknown" => "x") }.to raise_error(
        ArgumentError,
        /Unknown column name/,
      )
    end

    it "does not resolve system columns" do
      expect { resolver.resolve("id" => 1) }.to raise_error(ArgumentError, /Unknown column name/)
    end
  end

  describe "#validate_column!" do
    it "returns nil for known columns" do
      expect(resolver.validate_column!("email")).to be_nil
    end

    it "raises for unknown column names" do
      expect { resolver.validate_column!("unknown") }.to raise_error(
        ArgumentError,
        /Unknown column name/,
      )
    end
  end
end
