# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "del@test.com") }

    let(:filter) do
      {
        "type" => "and",
        "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "del@test.com" }],
      }
    end
    let(:params) { { data_table_id: data_table.id, filter: filter } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, filter: filter } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when filter is missing" do
      let(:params) { { data_table_id: data_table.id, filter: {} } }

      it { is_expected.to fail_with_an_invalid_model(:query) }
    end

    context "when matching rows exist" do
      it { is_expected.to run_successfully }

      it "destroys the matching rows" do
        row_id = row["id"]
        result
        expect(find_data_table_row(data_table, row_id)).to be_nil
      end

      it "resets the cached size after deleting" do
        allow(DiscourseWorkflows::DataTables::Facade).to receive(
          :reset_storage_cache!,
        ).and_call_original

        result

        expect(DiscourseWorkflows::DataTables::Facade).to have_received(:reset_storage_cache!).once
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

      it { is_expected.to run_successfully }
    end
  end
end
