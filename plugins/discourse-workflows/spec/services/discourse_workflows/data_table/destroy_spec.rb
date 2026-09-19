# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:data_table, :discourse_workflows_data_table)

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

    context "when data table is referenced by a workflow node" do
      fab!(:workflow) do
        Fabricate(
          :discourse_workflows_workflow,
          name: "My Workflow",
          created_by: admin,
          nodes: [
            {
              "id" => "data-table-1",
              "type" => "action:data_table",
              "typeVersion" => "1.0",
              "name" => "Data Table",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "parameters" => {
                "data_table_id" => data_table.id,
              },
              "credentials" => {
              },
            },
          ],
          connections: {
          },
        )
      end

      before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

      it { is_expected.to fail_a_policy(:data_table_not_in_use) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "destroys the data table" do
        expect { result }.to change { DiscourseWorkflows::DataTable.exists?(data_table.id) }.from(
          true,
        ).to(false)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)

        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_data_table_destroyed")
        expect(log.subject).to eq(data_table.name)
      end
    end
  end
end
