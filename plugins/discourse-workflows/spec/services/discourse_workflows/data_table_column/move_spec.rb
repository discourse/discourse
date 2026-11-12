# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Move do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_name) }
    it { is_expected.to validate_presence_of(:position) }
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
          { "name" => "active", "type" => "boolean" },
        ],
      )
    end

    let(:params) { { data_table_id: data_table.id, column_name: "active", position: 0 } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: data_table.id, column_name: "active", position: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the data table does not exist" do
      let(:params) { { data_table_id: -1, column_name: "active", position: 0 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the column does not exist" do
      let(:params) { { data_table_id: data_table.id, column_name: "nonexistent", position: 0 } }

      it { is_expected.to fail_a_policy(:column_exists) }
    end

    context "when trying to move a reserved column" do
      let(:params) { { data_table_id: data_table.id, column_name: "id", position: 1 } }

      it { is_expected.to fail_a_policy(:not_reserved_column) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "moves the column" do
        result
        expect(data_table.reload.column_order).to eq(%w[active email score])
      end
    end
  end
end
