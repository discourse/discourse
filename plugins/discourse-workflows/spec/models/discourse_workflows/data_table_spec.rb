# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  describe "#user_columns" do
    it "excludes system columns" do
      expect(data_table.user_columns.map { _1["name"] }).to eq(%w[email score])
    end
  end
end
