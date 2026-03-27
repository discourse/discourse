# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Rename do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@example.com") }

    let(:column) { data_table.columns.first }
    let(:params) { { data_table_id: data_table.id, column_id: column.id, name: "contact_email" } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, column_id: nil, name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the data table does not exist" do
      let(:params) { { data_table_id: -1, column_id: column.id, name: "contact_email" } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the column does not exist" do
      let(:params) { { data_table_id: data_table.id, column_id: -1, name: "contact_email" } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "logs a staff action" do
        result
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_data_table_column_renamed",
          subject: data_table.name,
          previous_value: "email",
          new_value: "contact_email",
        )
      end

      it "renames the column metadata" do
        result

        expect(column.reload.name).to eq("contact_email")
      end

      it "preserves existing row data" do
        result

        row_data = find_data_table_row(data_table, row["id"])
        expect(row_data["contact_email"]).to eq("test@example.com")
        expect(row_data).not_to have_key("email")
      end
    end
  end
end
