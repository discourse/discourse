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

  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }

  describe "#columns" do
    it "orders user columns by column_order between id and the timestamps" do
      DiscourseWorkflows::DataTables::Facade.new(data_table).add_column!("notes", "string")
      data_table.update!(column_order: %w[score email])

      expect(data_table.columns.map { _1["name"] }).to eq(
        %w[id score email notes created_at updated_at],
      )
    end
  end

  describe "#user_columns" do
    it "excludes system columns" do
      expect(data_table.user_columns.map { _1["name"] }).to eq(%w[email score])
    end
  end
end
