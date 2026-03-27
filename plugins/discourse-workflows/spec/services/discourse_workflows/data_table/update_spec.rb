# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table, :discourse_workflows_data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        name: "original",
        columns: [{ "name" => "value", "type" => "string" }],
      )
    end

    let(:params) { { data_table_id: data_table.id, name: "updated" } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when updating name" do
      let(:params) { { data_table_id: data_table.id, name: "renamed" } }

      it { is_expected.to run_successfully }

      it "updates the name" do
        result
        expect(data_table.reload.name).to eq("renamed")
      end

      it "resets the cached size after updating" do
        allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!).and_call_original

        result

        expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!).once
      end
    end

    context "when doing a partial update" do
      let(:params) { { data_table_id: data_table.id, name: "partial" } }

      it { is_expected.to run_successfully }

      it "preserves other fields" do
        result
        data_table.reload
        expect(data_table.name).to eq("partial")
        expect(data_table.columns.map(&:name)).to eq(["value"])
      end
    end
  end
end
