# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRowsRepository do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
        { "name" => "active", "type" => "boolean" },
        { "name" => "joined_at", "type" => "date" },
      ],
    )
  end

  let(:repository) { described_class.new(data_table) }

  let!(:row_1) do
    insert_data_table_row(
      data_table,
      {
        "email" => "alice@example.com",
        "score" => 90,
        "active" => true,
        "joined_at" => "2024-01-10",
      },
    )
  end

  let!(:row_2) do
    insert_data_table_row(
      data_table,
      {
        "email" => "bob@example.com",
        "score" => 60,
        "active" => false,
        "joined_at" => "2024-01-11",
      },
    )
  end

  let!(:row_3) do
    insert_data_table_row(
      data_table,
      { "email" => "carol_data@example.com", "score" => nil, "active" => nil },
    )
  end

  describe "#insert" do
    it "fills omitted columns with null values" do
      row = repository.insert({})

      expect(row.slice("email", "score", "active", "joined_at")).to eq(
        "email" => nil,
        "score" => nil,
        "active" => nil,
        "joined_at" => nil,
      )
    end

    it "raises for unknown columns" do
      expect { repository.insert("unknown" => "value") }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Unknown column name 'unknown'",
      )
    end
  end

  describe "#get_many_and_count" do
    it "returns all rows without a filter" do
      result = repository.get_many_and_count

      expect(result[:count]).to eq(3)
      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"], row_2["id"], row_3["id"]])
    end

    it "supports case-insensitive contains filtering without explicit wildcards" do
      result =
        repository.get_many_and_count(
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "email", "condition" => "ilike", "value" => "ALICE" }],
          },
        )

      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"]])
    end

    it "treats underscore literally in like filters" do
      result =
        repository.get_many_and_count(
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "email", "condition" => "like", "value" => "%_data%" }],
          },
        )

      expect(result[:rows].map { |row| row["id"] }).to eq([row_3["id"]])
    end

    it "treats missing values as null by normalizing inserts" do
      result =
        repository.get_many_and_count(
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "joined_at", "condition" => "eq", "value" => nil }],
          },
        )

      expect(result[:rows].map { |row| row["id"] }).to eq([row_3["id"]])
    end

    it "includes null rows for non-null neq filters" do
      result =
        repository.get_many_and_count(
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "score", "condition" => "neq", "value" => 90 }],
          },
        )

      expect(result[:rows].map { |row| row["id"] }).to eq([row_2["id"], row_3["id"]])
    end

    it "sorts and limits deterministically" do
      result = repository.get_many_and_count(sort_by: "score", sort_direction: "desc", limit: 2)

      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"], row_2["id"]])
    end

    it "raises for invalid filter conditions" do
      expect {
        repository.get_many_and_count(
          filter: {
            "type" => "and",
            "filters" => [
              { "columnName" => "email", "condition" => "invalid", "value" => "alice" },
            ],
          },
        )
      }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Unsupported filter condition 'invalid'",
      )
    end

    it "raises for invalid sort columns" do
      expect { repository.get_many_and_count(sort_by: "missing") }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Unknown sort column 'missing'",
      )
    end
  end
end
