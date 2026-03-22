# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)

    let(:params) { { name: "my_table", columns: } }
    let(:columns) { [{ "name" => "value", "type" => "string" }] }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when model is invalid" do
      let(:columns) { [{ "name" => "value", "type" => "invalid_type" }] }

      it { is_expected.to fail_with_an_invalid_model(:data_table) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the data table" do
        expect { result }.to change(DiscourseWorkflows::DataTable, :count).by(1)
        expect(DiscourseWorkflows::DataTable.last).to have_attributes(
          name: "my_table",
          columns: [{ "name" => "value", "type" => "string" }],
        )
      end

      it "returns the created data table" do
        expect(result[:data_table]).to have_attributes(
          name: "my_table",
          columns: [{ "name" => "value", "type" => "string" }],
        )
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_data_table_created")
        expect(log.subject).to eq("my_table")
      end
    end
  end
end
