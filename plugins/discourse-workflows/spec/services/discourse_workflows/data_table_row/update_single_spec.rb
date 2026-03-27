# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::UpdateSingle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:row_id) }
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

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com", "score" => 1) }

    let(:params) { { data_table_id: data_table.id, row_id: row["id"], data: { "score" => 99 } } }
    let(:storage_limit_error) { DiscourseWorkflows::DataTableValidationError.new("quota full") }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, row_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, row_id: row["id"], data: { "score" => 99 } } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when row does not exist" do
      let(:params) { { data_table_id: data_table.id, row_id: -1, data: { "score" => 99 } } }

      it { is_expected.to fail_to_find_a_model(:row) }
    end

    context "when the storage limit is exceeded" do
      before do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:validate_size!).and_raise(
          storage_limit_error,
        )
      end

      it "raises the validation error before updating" do
        expect { result }.to raise_error(
          DiscourseWorkflows::DataTableValidationError,
          storage_limit_error.message,
        )
      end
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

      it "resets the cached size after updating" do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!).and_call_original

        result

        expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!).once
      end
    end
  end
end
