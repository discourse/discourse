# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow do
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

  describe ".normalize_row_data" do
    it "casts known values" do
      result =
        described_class.normalize_row_data(
          data_table,
          {
            "email" => "test@example.com",
            "score" => "42",
            "active" => "true",
            "joined_at" => "2024-01-15",
          },
          fill_missing: true,
        )

      expect(result["email"]).to eq("test@example.com")
      expect(result["score"]).to eq(42)
      expect(result["active"]).to eq(true)
      expect(result["joined_at"]).to be_a(Time)
    end

    it "fills omitted columns with nil when requested" do
      result =
        described_class.normalize_row_data(
          data_table,
          { "email" => "test@example.com" },
          fill_missing: true,
        )

      expect(result).to eq(
        "email" => "test@example.com",
        "score" => nil,
        "active" => nil,
        "joined_at" => nil,
      )
    end

    it "rejects unknown columns" do
      expect {
        described_class.normalize_row_data(
          data_table,
          { "email" => "test@example.com", "unknown_field" => "value" },
          fill_missing: false,
        )
      }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Unknown column name 'unknown_field'",
      )
    end

    it "rejects invalid numbers" do
      expect {
        described_class.normalize_row_data(
          data_table,
          { "score" => "not a number" },
          fill_missing: false,
        )
      }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Value 'not a number' does not match column type 'number'",
      )
    end

    it "rejects invalid booleans" do
      expect {
        described_class.normalize_row_data(data_table, { "active" => "maybe" }, fill_missing: false)
      }.to raise_error(
        DiscourseWorkflows::DataTableValidationError,
        "Value 'maybe' does not match column type 'boolean'",
      )
    end

    it "converts blank numeric and date values to nil" do
      result =
        described_class.normalize_row_data(
          data_table,
          { "score" => "", "joined_at" => "" },
          fill_missing: false,
        )

      expect(result).to eq("score" => nil, "joined_at" => nil)
    end
  end
end
