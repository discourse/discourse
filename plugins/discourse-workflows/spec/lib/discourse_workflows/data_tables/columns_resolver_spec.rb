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

    it "raises when the input is not a hash or an array of column fields" do
      ["oops", 42, [1, 2], [{ "value" => "x" }]].each do |input|
        expect { resolver.resolve(input) }.to raise_error(
          ArgumentError,
          /Columns must be an object of column names to values/,
        )
      end
    end

    it "raises for unknown and system column names" do
      %w[unknown id].each do |name|
        expect { resolver.resolve(name => 1) }.to raise_error(ArgumentError, /Unknown column name/)
      end
    end
  end

  describe ".column_pairs" do
    it "returns nil when the columns are not keyed by column name" do
      ["={{ $json }}", ["oops", { "columnName" => "email" }]].each do |input|
        expect(described_class.column_pairs(input)).to be_nil
      end
    end
  end

  describe "#validate_column!" do
    it "returns nil for known columns" do
      expect(resolver.validate_column!("email")).to be_nil
    end
  end
end
