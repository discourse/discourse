# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:column_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: admin.guardian) }

    fab!(:admin)

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    fab!(:row) { insert_data_table_row(data_table, "email" => "test@example.com") }

    let(:params) { { data_table_id: data_table.id, name: "score", column_type: "number" } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { data_table_id: nil, name: nil, column_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the data table does not exist" do
      let(:params) { { data_table_id: -1, name: "score", column_type: "number" } }

      it { is_expected.to fail_to_find_a_model(:data_table) }
    end

    context "when the column type is invalid" do
      let(:params) { { data_table_id: data_table.id, name: "score", column_type: "invalid" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the name is reserved" do
      let(:params) { { data_table_id: data_table.id, name: "id", column_type: "string" } }

      it { is_expected.to fail_a_contract }
    end

    context "when column limit is reached" do
      before do
        facade = DiscourseWorkflows::DataTableFacade.new(data_table)
        29.times { |i| facade.add_column!("col_#{i}", "string") }
      end

      it { is_expected.to fail_a_policy(:column_limit_not_reached) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates the column in the storage table" do
        result
        columns = data_table.columns.map { |c| c["name"] }
        expect(columns).to include("email", "score")
      end

      it "logs a staff action" do
        result
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_data_table_column_created",
          subject: data_table.name,
        )
      end

      it "preserves existing row data" do
        result

        expect(find_data_table_row(data_table, row["id"])).to include(
          "email" => "test@example.com",
          "score" => nil,
        )
      end
    end
  end
end
