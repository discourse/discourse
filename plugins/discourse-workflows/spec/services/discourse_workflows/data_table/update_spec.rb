# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        name: "original",
        columns: [{ "name" => "value", "type" => "string" }],
      )
    end

    let(:params) { { data_table_id: data_table.id, name: "updated" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when contract is invalid" do
      let(:params) { { data_table_id: data_table.id, name: "" } }

      it { is_expected.to fail_a_contract }
    end

    context "when name fails model validation" do
      let(:params) { { data_table_id: data_table.id, name: "invalid-name!" } }

      it { is_expected.to fail_with_an_invalid_model(:data_table) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "updates the name" do
        expect { result }.to change { data_table.reload.name }.from("original").to("updated")
      end

      it "preserves existing columns" do
        expect { result }.not_to change { data_table.reload.columns.map { |c| c["name"] } }
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_data_table_updated",
          subject: "updated",
        )
      end
    end
  end
end
