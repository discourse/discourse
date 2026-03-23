# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Get do
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

    fab!(:row_1) { insert_data_table_row(data_table, "email" => "alice@test.com", "score" => 10) }
    fab!(:row_2) { insert_data_table_row(data_table, "email" => "bob@test.com", "score" => 20) }

    let(:params) { { data_table_id: data_table.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when data table does not exist" do
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when no filter is provided" do
      it { is_expected.to run_successfully }

      it "returns all rows" do
        expect(result[:rows].count).to eq(2)
        expect(result[:count]).to eq(2)
      end
    end

    context "when filter matches a subset of rows" do
      let(:params) do
        {
          data_table_id: data_table.id,
          filter: {
            "type" => "and",
            "filters" => [
              { "columnName" => "email", "condition" => "eq", "value" => "alice@test.com" },
            ],
          },
        }
      end

      it { is_expected.to run_successfully }

      it "returns only matching rows" do
        expect(result[:rows].count).to eq(1)
        expect(result[:rows].first["email"]).to eq("alice@test.com")
      end
    end

    context "when filter matches no rows" do
      let(:params) do
        {
          data_table_id: data_table.id,
          filter: {
            "type" => "and",
            "filters" => [
              { "columnName" => "email", "condition" => "eq", "value" => "nonexistent@test.com" },
            ],
          },
        }
      end

      it { is_expected.to run_successfully }

      it "returns an empty result" do
        expect(result[:rows].count).to eq(0)
        expect(result[:count]).to eq(0)
      end
    end
  end
end
