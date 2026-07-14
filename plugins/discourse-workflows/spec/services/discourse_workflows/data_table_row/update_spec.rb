# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
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

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com", "score" => 1) }

    let(:filter) do
      {
        "type" => "and",
        "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "test@test.com" }],
      }
    end
    let(:params) { { data_table_id: data_table.id, filter: filter, data: { "score" => 42 } } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, filter: filter, data: {} } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the storage limit is exceeded" do
      before do
        allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
          false,
        )
      end

      it { is_expected.to fail_a_policy(:within_storage_limit) }
    end

    context "when filter is missing" do
      let(:params) { { data_table_id: data_table.id, filter: {}, data: {} } }

      it { is_expected.to fail_with_an_invalid_model(:query) }
    end

    context "when row data contains unknown columns" do
      let(:params) { { data_table_id: data_table.id, filter: filter, data: { "unknown" => "x" } } }

      it { is_expected.to fail_with_an_invalid_model(:row_input) }
    end

    context "when matching rows exist" do
      it { is_expected.to run_successfully }

      it "returns the updated count" do
        expect(result[:updated_count]).to eq(1)
      end

      it "updates matching rows with merged data" do
        result
        expect(find_data_table_row(data_table, row["id"]).slice("email", "score")).to eq(
          "email" => "test@test.com",
          "score" => 42,
        )
      end
    end

    context "when no rows match the filter" do
      let(:filter) do
        {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "nonexistent@test.com" },
          ],
        }
      end

      it { is_expected.to fail_a_step(:ensure_rows_matched) }
    end
  end
end
