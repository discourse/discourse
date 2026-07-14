# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:dependencies) { { guardian: admin.guardian } }

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@example.com", "score" => 5) }

    let(:params) { { data_table_id: data_table.id, column_name: "email" } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, column_name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the data table does not exist" do
      let(:params) { { data_table_id: -1, column_name: "email" } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the column does not exist" do
      let(:params) { { data_table_id: data_table.id, column_name: "nonexistent" } }

      it { is_expected.to fail_a_policy(:column_exists) }
    end

    context "when trying to delete a reserved column" do
      let(:params) { { data_table_id: data_table.id, column_name: "id" } }

      it { is_expected.to fail_a_policy(:not_reserved_column) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "removes the column from the storage table" do
        result
        column_names = data_table.columns.map { |c| c["name"] }
        expect(column_names).not_to include("email")
        expect(column_names).to include("score")
      end

      it "logs a staff action" do
        result
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_data_table_column_destroyed",
          subject: data_table.name,
        )
      end

      it "preserves the remaining row data" do
        result

        row_data = find_data_table_row(data_table, row["id"])
        expect(row_data["score"]).to eq(5)
        expect(row_data).not_to have_key("email")
      end
    end
  end
end
