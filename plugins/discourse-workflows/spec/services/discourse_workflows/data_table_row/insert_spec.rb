# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Insert do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end

    let(:params) do
      { data_table_id: data_table.id, data: { "email" => "test@test.com", "score" => "42" } }
    end

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1, data: {} } }

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

    context "when row data contains unknown columns" do
      let(:params) { { data_table_id: data_table.id, data: { "unknown_col" => "value" } } }

      it { is_expected.to fail_with_an_invalid_model(:row_input) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "inserts a new row with cast data" do
        expect { result }.to change { count_data_table_rows(data_table) }.by(1)

        row = list_data_table_rows(data_table)[:rows].last
        expect(row.slice("email", "score")).to eq("email" => "test@test.com", "score" => 42)
      end

      it "returns the created row" do
        expect(result[:row].slice("email", "score")).to eq(
          "email" => "test@test.com",
          "score" => 42,
        )
      end

      it "resets the cached size after inserting" do
        allow(DiscourseWorkflows::DataTables::Facade).to receive(
          :reset_storage_cache!,
        ).and_call_original

        result

        expect(DiscourseWorkflows::DataTables::Facade).to have_received(:reset_storage_cache!).once
      end
    end
  end
end
