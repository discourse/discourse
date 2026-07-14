# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::UpdateSingle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:row_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com", "score" => 1) }

    let(:params) { { data_table_id: data_table.id, row_id: row["id"], data: { "score" => 99 } } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, row_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, row_id: row["id"], data: { "score" => 99 } } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the storage limit is exceeded" do
      before do
        allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
          false,
        )
      end

      it { is_expected.to fail_a_policy(:within_storage_limit) }
    end

    context "when row does not exist" do
      let(:params) { { data_table_id: data_table.id, row_id: -1, data: { "score" => 99 } } }

      it { is_expected.to fail_to_find_a_model(:existing_row) }
    end

    context "when row data contains unknown columns" do
      let(:params) do
        { data_table_id: data_table.id, row_id: row["id"], data: { "unknown" => "x" } }
      end

      it { is_expected.to fail_with_an_invalid_model(:row_input) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "merges and casts the updated data" do
        result
        expect(find_data_table_row(data_table, row["id"]).slice("email", "score")).to eq(
          "email" => "test@test.com",
          "score" => 99,
        )
      end
    end
  end
end
