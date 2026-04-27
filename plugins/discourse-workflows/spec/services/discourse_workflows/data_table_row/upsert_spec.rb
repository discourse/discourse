# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Upsert do
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

    let(:filter) do
      {
        "type" => "and",
        "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "test@test.com" }],
      }
    end
    let(:params) do
      {
        data_table_id: data_table.id,
        filter: filter,
        data: {
          "email" => "test@test.com",
          "score" => 42,
        },
      }
    end
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

    context "when no existing rows match" do
      it { is_expected.to run_successfully }

      it "inserts a new row" do
        expect { result }.to change { count_data_table_rows(data_table) }.by(1)

        row = list_data_table_rows(data_table)[:rows].last
        expect(row.slice("email", "score")).to eq("email" => "test@test.com", "score" => 42)
      end
    end

    context "when existing rows match" do
      fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com", "score" => 10) }

      it { is_expected.to run_successfully }

      it "returns the updated count" do
        expect(result[:upsert_result][:updated_count]).to eq(1)
      end

      it "updates the existing row with merged data" do
        result
        expect(find_data_table_row(data_table, row["id"]).slice("email", "score")).to eq(
          "email" => "test@test.com",
          "score" => 42,
        )
      end

      it "does not insert a new row" do
        expect { result }.not_to change { count_data_table_rows(data_table) }
      end
    end
  end
end
