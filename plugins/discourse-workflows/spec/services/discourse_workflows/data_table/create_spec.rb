# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { name: "my_table", columns: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:columns) { [{ "name" => "value", "type" => "string" }] }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when model is invalid" do
      let(:params) { { name: "123 invalid!", columns: [] } }

      it { is_expected.to fail_with_an_invalid_model(:data_table) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the data table with columns" do
        expect { result }.to change(DiscourseWorkflows::DataTable, :count).by(1)

        data_table = DiscourseWorkflows::DataTable.last
        expect(data_table.name).to eq("my_table")
        expect(data_table.columns).to include({ "name" => "value", "type" => "string" })
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_data_table_created")
        expect(log.subject).to eq("my_table")
      end

      it "resets the cached size" do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!).and_call_original

        result

        expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!).once
      end
    end

    context "when columns are omitted" do
      let(:params) { { name: "empty_table" } }

      it { is_expected.to run_successfully }

      it "creates the data table without columns" do
        result
        data_table = DiscourseWorkflows::DataTable.last
        expect(data_table.name).to eq("empty_table")
        user_columns =
          data_table.columns.reject do |c|
            DiscourseWorkflows::DataTableStorage::RESERVED_COLUMN_NAMES.include?(c["name"])
          end
        expect(user_columns).to be_empty
      end
    end
  end
end
