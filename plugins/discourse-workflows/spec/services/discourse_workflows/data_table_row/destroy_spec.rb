# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRow::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)
      fab!(:data_table, :discourse_workflows_data_table)
      fab!(:row) { insert_data_table_row(data_table) }

      let(:params) { { data_table_id: data_table.id, row_id: row["id"] } }
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "with row_id (single-row delete)" do
      fab!(:data_table, :discourse_workflows_data_table)
      fab!(:row) { insert_data_table_row(data_table) }

      let(:params) { { data_table_id: data_table.id, row_id: row["id"] } }

      context "when data table does not exist" do
        let(:params) { { data_table_id: -1, row_id: row["id"] } }

        it { is_expected.to fail_to_find_a_model(:data_table) }
      end

      context "when row does not exist" do
        let(:params) { { data_table_id: data_table.id, row_id: -1 } }

        it { is_expected.to fail_to_find_a_model(:row) }
      end

      context "when everything is ok" do
        it { is_expected.to run_successfully }

        it "destroys the row" do
          result
          expect(find_data_table_row(data_table, row["id"])).to be_nil
        end
      end
    end

    context "with row_ids (batch delete)" do
      fab!(:data_table, :discourse_workflows_data_table)
      fab!(:row_1) { insert_data_table_row(data_table) }
      fab!(:row_2) { insert_data_table_row(data_table) }

      let(:params) { { data_table_id: data_table.id, row_ids: [row_1["id"], row_2["id"]] } }

      context "when data table does not exist" do
        let(:params) { { data_table_id: -1, row_ids: [row_1["id"]] } }

        it { is_expected.to fail_to_find_a_model(:data_table) }
      end

      context "when everything is ok" do
        it { is_expected.to run_successfully }

        it "destroys the rows" do
          result
          expect(find_data_table_row(data_table, row_1["id"])).to be_nil
          expect(find_data_table_row(data_table, row_2["id"])).to be_nil
        end

        it "returns the deleted count" do
          expect(result[:deleted_count]).to eq(2)
        end

        it "normalizes row_ids" do
          params[:row_ids] = [row_1["id"].to_s, row_2["id"].to_s, row_1["id"].to_s]
          expect(result[:deleted_count]).to eq(2)
        end
      end

      context "when row_ids exceeds the maximum" do
        let(:params) do
          {
            data_table_id: data_table.id,
            row_ids: (1..(DiscourseWorkflows::DataTableRow::Destroy::MAX_BULK_DELETE + 1)).to_a,
          }
        end

        it { is_expected.to fail_a_contract }
      end
    end

    context "with filter (query-based delete)" do
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
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "del@test.com" },
          ],
        }
      end
      let(:params) { { data_table_id: data_table.id, filter: filter } }

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

        it "leaves existing rows intact" do
          row_id = row["id"]
          expect { result }.not_to change { find_data_table_row(data_table, row_id) }
        end
      end
    end
  end
end
