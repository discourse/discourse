# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Rename do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_name) }
    it { is_expected.to validate_presence_of(:name) }
    it do
      is_expected.to validate_length_of(:name).is_at_most(
        DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH,
      )
    end
    it { is_expected.to allow_values("valid_col", "column_1", "_col").for(:name) }
    it do
      is_expected.not_to allow_values("123col", "col space", "col!@#", "id", "created_at").for(
        :name,
      )
    end
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
        ],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@example.com") }

    let(:params) { { data_table_id: data_table.id, column_name: "email", name: "contact_email" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: data_table.id, column_name: "email", name: "123-invalid" } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the data table does not exist" do
      let(:params) { { data_table_id: -1, column_name: "email", name: "contact_email" } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the column does not exist" do
      let(:params) do
        { data_table_id: data_table.id, column_name: "nonexistent", name: "contact_email" }
      end

      it { is_expected.to fail_a_policy(:column_exists) }
    end

    context "when trying to rename a reserved column" do
      let(:params) { { data_table_id: data_table.id, column_name: "id", name: "contact_email" } }

      it { is_expected.to fail_a_policy(:not_reserved_column) }
    end

    context "when the new name is the same as the old name" do
      let(:params) { { data_table_id: data_table.id, column_name: "email", name: "email" } }

      it { is_expected.to fail_a_policy(:name_differs) }
    end

    context "when the new name already exists" do
      let(:params) { { data_table_id: data_table.id, column_name: "email", name: "score" } }

      it { is_expected.to fail_a_policy(:name_available) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "preserves existing row data" do
        result
        row_data = find_data_table_row(data_table, row["id"])
        expect(row_data["contact_email"]).to eq("test@example.com")
        expect(row_data).not_to have_key("email")
      end

      it "logs a staff action" do
        result
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_data_table_column_renamed",
          subject: data_table.name,
          previous_value: "email",
          new_value: "contact_email",
        )
      end
    end
  end
end
