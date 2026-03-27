# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Delete do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@example.com", "score" => 5) }

    let(:column) { data_table.columns.find_by(name: "email") }
    let(:params) { { data_table_id: data_table.id, column_id: column.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "removes the column metadata" do
        expect { result }.to change(data_table.columns, :count).by(-1)
        expect(data_table.reload.columns.map(&:name)).to eq(["score"])
      end

      it "preserves the remaining row data" do
        result

        row_data = find_data_table_row(data_table, row["id"])
        expect(row_data["score"]).to eq(5)
        expect(row_data).not_to have_key("email")
      end
    end
  end
end
