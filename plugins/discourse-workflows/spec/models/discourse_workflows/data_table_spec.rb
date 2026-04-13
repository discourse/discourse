# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable do
  describe "#columns" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    it "returns columns from the storage table" do
      columns = data_table.columns
      expect(columns.map { |c| c["name"] }).to include("email")
    end
  end
end
