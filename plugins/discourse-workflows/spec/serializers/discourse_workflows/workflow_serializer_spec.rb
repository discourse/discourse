# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSerializer do
  fab!(:workflow, :discourse_workflows_workflow)

  describe "#as_json" do
    def fabricate_execution_with_run_data(status:, created_at:, run_data: nil)
      execution =
        Fabricate(:discourse_workflows_execution, workflow: workflow, status: status, created_at:)
      if run_data
        Fabricate(
          :discourse_workflows_execution_data,
          execution: execution,
          data: {
            "run_data" => run_data,
          },
        )
      end
      execution
    end

    it "returns run data from the latest execution when it failed" do
      successful_run_data = { "SQL" => [{ "outputs" => [{ "items" => [] }] }] }
      fabricate_execution_with_run_data(
        status: :success,
        created_at: 1.minute.ago,
        run_data: successful_run_data,
      )
      failed_run_data = {
        "SQL" => [{ "outputs" => [{ "items" => [{ "json" => { "answer" => 42 } }] }] }],
      }
      fabricate_execution_with_run_data(
        status: :error,
        created_at: Time.current,
        run_data: failed_run_data,
      )

      serialized = described_class.new(workflow, root: false).as_json

      expect(serialized[:last_execution_run_data]).to eq(failed_run_data)
    end

    it "returns run data from the latest execution when it succeeded" do
      failed_run_data = { "SQL" => [{ "outputs" => [{ "items" => [] }] }] }
      fabricate_execution_with_run_data(
        status: :error,
        created_at: 1.minute.ago,
        run_data: failed_run_data,
      )
      successful_run_data = {
        "SQL" => [{ "outputs" => [{ "items" => [{ "json" => { "answer" => 42 } }] }] }],
      }
      fabricate_execution_with_run_data(
        status: :success,
        created_at: Time.current,
        run_data: successful_run_data,
      )

      serialized = described_class.new(workflow, root: false).as_json

      expect(serialized[:last_execution_run_data]).to eq(successful_run_data)
    end

    it "returns run data from the last finished execution when a running execution is newer" do
      successful_run_data = { "SQL" => [{ "outputs" => [{ "items" => [] }] }] }
      fabricate_execution_with_run_data(
        status: :success,
        created_at: 1.minute.ago,
        run_data: successful_run_data,
      )
      running_run_data = {
        "SQL" => [{ "outputs" => [{ "items" => [{ "json" => { "answer" => 42 } }] }] }],
      }
      fabricate_execution_with_run_data(
        status: :running,
        created_at: Time.current,
        run_data: running_run_data,
      )

      serialized = described_class.new(workflow, root: false).as_json

      expect(serialized[:last_execution_run_data]).to eq(successful_run_data)
    end

    it "returns run data from the highest-id execution when executions share a created_at" do
      older_run_data = { "SQL" => [{ "outputs" => [{ "items" => [] }] }] }
      newer_run_data = {
        "SQL" => [{ "outputs" => [{ "items" => [{ "json" => { "answer" => 42 } }] }] }],
      }
      created_at = 1.minute.ago
      fabricate_execution_with_run_data(
        status: :success,
        created_at: created_at,
        run_data: older_run_data,
      )
      fabricate_execution_with_run_data(
        status: :success,
        created_at: created_at,
        run_data: newer_run_data,
      )

      serialized = described_class.new(workflow, root: false).as_json

      expect(serialized[:last_execution_run_data]).to eq(newer_run_data)
    end
  end
end
