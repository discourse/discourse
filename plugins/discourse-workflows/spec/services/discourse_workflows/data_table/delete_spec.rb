# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Delete do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)
    fab!(:data_table, :discourse_workflows_data_table)

    let(:params) { { data_table_id: data_table.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "destroys the data table" do
        result
        expect(DiscourseWorkflows::DataTable.exists?(data_table.id)).to eq(false)
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_data_table_destroyed")
        expect(log.subject).to eq(data_table.name)
      end

      it "resets the cached size after deleting the table" do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!).and_call_original

        result

        expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!).once
      end
    end
  end
end
