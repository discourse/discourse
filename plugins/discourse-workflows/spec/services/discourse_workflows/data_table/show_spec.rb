# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Show do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table, :discourse_workflows_data_table)

    let(:params) { { data_table_id: data_table.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when data table exists" do
      it { is_expected.to run_successfully }

      it "returns the data table" do
        expect(result[:data_table]).to eq(data_table)
      end
    end
  end
end
