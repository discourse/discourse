# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::Storage do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
        { "name" => "active", "type" => "boolean" },
        { "name" => "happened_at", "type" => "date" },
      ],
    )
  end

  describe ".columns" do
    it "returns all columns with mapped types ordered by attnum" do
      columns = described_class.columns(data_table.id)

      expect(columns).to eq(
        [
          { "name" => "id", "type" => "number" },
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
          { "name" => "active", "type" => "boolean" },
          { "name" => "happened_at", "type" => "date" },
          { "name" => "created_at", "type" => "date" },
          { "name" => "updated_at", "type" => "date" },
        ],
      )
    end

    it "returns only system columns for a table with no user columns" do
      empty_table = Fabricate(:discourse_workflows_data_table, columns: [])

      columns = described_class.columns(empty_table.id)

      expect(columns.map { |c| c["name"] }).to eq(%w[id created_at updated_at])
    end
  end
end
