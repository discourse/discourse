# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::DestroySingle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:row_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table, :discourse_workflows_data_table)

    fab!(:row) { insert_data_table_row(data_table) }

    let(:params) { { data_table_id: data_table.id, row_id: row["id"] } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, row_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, row_id: row["id"] } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when row does not exist" do
      let(:params) { { data_table_id: data_table.id, row_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:row) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the row" do
        result
        expect(find_data_table_row(data_table, row["id"])).to be_nil
      end

      it "resets the cached size after deleting" do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!).and_call_original

        result

        expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!).once
      end
    end
  end
end
