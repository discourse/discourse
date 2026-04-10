# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::BulkDestroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:row_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table, :discourse_workflows_data_table)

    fab!(:row_1) { insert_data_table_row(data_table) }
    fab!(:row_2) { insert_data_table_row(data_table) }

    let(:params) { { data_table_id: data_table.id, row_ids: [row_1["id"], row_2["id"]] } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, row_ids: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, row_ids: [row_1["id"]] } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "destroys the rows" do
        result
        expect(find_data_table_row(data_table, row_1["id"])).to be_nil
        expect(find_data_table_row(data_table, row_2["id"])).to be_nil
      end

      it "returns the deleted count" do
        expect(result[:deleted_count]).to eq(2)
      end

      it "resets the storage cache" do
        allow(DiscourseWorkflows::DataTableFacade).to receive(
          :reset_storage_cache!,
        ).and_call_original

        result

        expect(DiscourseWorkflows::DataTableFacade).to have_received(:reset_storage_cache!).once
      end
    end
  end
end
