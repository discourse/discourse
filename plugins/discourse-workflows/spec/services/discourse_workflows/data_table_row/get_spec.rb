# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Get do
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

    fab!(:row_1) { insert_data_table_row(data_table, "email" => "alice@test.com", "score" => 10) }
    fab!(:row_2) { insert_data_table_row(data_table, "email" => "bob@test.com", "score" => 20) }

    let(:params) { { data_table_id: data_table.id } }
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
      let(:params) { { data_table_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when filter contains unknown columns" do
      let(:params) do
        {
          data_table_id: data_table.id,
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "nonexistent", "condition" => "eq", "value" => "x" }],
          },
        }
      end

      it { is_expected.to fail_with_an_invalid_model(:query) }
    end

    context "when no filter is provided" do
      it { is_expected.to run_successfully }

      it "returns all rows" do
        expect(result[:query_result][:rows].count).to eq(2)
        expect(result[:query_result][:count]).to eq(2)
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
        expect(result[:query_result][:rows].count).to eq(1)
        expect(result[:query_result][:rows].first["email"]).to eq("alice@test.com")
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
        expect(result[:query_result][:rows].count).to eq(0)
        expect(result[:query_result][:count]).to eq(0)
      end
    end

    context "with sorting" do
      let(:params) { { data_table_id: data_table.id, sort_by: "score", sort_direction: "desc" } }

      it { is_expected.to run_successfully }

      it "returns rows in the specified order" do
        emails = result[:query_result][:rows].map { |r| r["email"] }
        expect(emails).to eq(%w[bob@test.com alice@test.com])
      end
    end

    context "with pagination" do
      let(:params) { { data_table_id: data_table.id, limit: 1, offset: 0 } }

      it { is_expected.to run_successfully }

      it "limits the returned rows" do
        expect(result[:query_result][:rows].count).to eq(1)
      end

      it "returns the total count" do
        expect(result[:query_result][:count]).to eq(2)
      end
    end
  end
end
