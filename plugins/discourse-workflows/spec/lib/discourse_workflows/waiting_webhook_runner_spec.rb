# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WaitingWebhookRunner do
  fab!(:user)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Manual"
        g.node "form-action-1",
               "action:form",
               name: "Waiting Form",
               configuration: {
                 "form_title" => "={{ $execution.workflow_name }}",
                 "form_description" => '=Counter was {{ $("Manual").context["counter"] }}',
                 "form_fields" => [
                   { "field_label" => "Feedback", "field_type" => "text", "required" => true },
                 ],
               }
        g.chain "trigger-1", "form-action-1"
      end
    Fabricate(:discourse_workflows_workflow, name: "Published workflow", published: true, **graph)
  end

  let(:guardian) { Guardian.new(user) }

  before { allow(MessageBus).to receive(:publish) }

  let!(:execution) do
    exec = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    ed = exec.execution_data
    ed.update!(
      data: {
        "entries" => ed.entries,
        "context" => ed.context_data,
        "node_contexts" => {
          "trigger-1" => {
            "counter" => 42,
          },
        },
      },
      workflow_data: ed.workflow_data,
    )
    exec
  end

  let(:signature) do
    DiscourseWorkflows::WaitingExecution.resume_signature(
      execution_id: execution.id,
      resume_token: execution.resume_token,
    )
  end

  def dispatch(http_method:, path: "", params: {}, signature: self.signature)
    described_class.call(
      execution_id: execution.id,
      signature: signature,
      http_method: http_method,
      path: path,
      node_type: "form",
      params: params,
      service_params: {
        guardian: guardian,
      },
    )
  end

  describe ".call" do
    it "serves waiting form status through the node webhook descriptor" do
      result = dispatch(http_method: "GET", path: "status")

      expect(result.status).to eq(:ok)
      expect(result.body).to eq(status: "form_waiting")
    end

    it "serves waiting form data through the node webhook context" do
      result = dispatch(http_method: "GET")

      expect(result.status).to eq(:ok)
      expect(result.body[:form_title]).to eq("Published workflow")
      expect(result.body[:form_description]).to eq("Counter was 42")
      expect(result.body).not_to have_key(:form_fields)
      expect(result.body).to include(
        data: {
          "feedback" => "",
        },
        fields: [
          {
            name: "feedback",
            title: "Feedback",
            type: "input",
            validation: "required",
            autofocus: false,
          },
        ],
      )
      expect(result.body[:form_waiting_url]).to be_present
      expect(result.body[:form_submit_url]).to be_present
      expect(result.body[:form_status_url]).to be_present
      expect(result.body.to_json).not_to include(execution.resume_token)
    end

    it "uses trigger query parameters as waiting form defaults" do
      execution.update!(trigger_data: { "form_query_parameters" => { "feedback" => "Prefill" } })

      result = dispatch(http_method: "GET")

      expect(result.body[:data]["feedback"]).to eq("Prefill")
    end

    it "returns structured validation errors from the waiting form webhook" do
      result = dispatch(http_method: "POST", params: { form_data: {} })

      expect(result.status).to eq(:unprocessable_entity)
      expect(result.body[:errors]).to contain_exactly(field_label: "Feedback", code: :missing)
    end

    it "resumes the execution with node returned workflow data" do
      freeze_time Time.utc(2026, 1, 1)

      result = dispatch(http_method: "POST", params: { form_data: { "feedback" => "Approved" } })

      expect(result.status).to eq(:ok)
      expect(result.body[:status]).to eq("success")
      expect(execution.reload.status).to eq("success")
      output = execution.execution_data.entries.dig("form-action-1", 0, "output", 0, "json")
      expect(output).to include(
        "feedback" => "Approved",
        "submitted_at" => "2026-01-01T00:00:00.000Z",
        "form_mode" => "production",
      )
    end

    it "returns not_found when the signature does not match" do
      result = dispatch(http_method: "GET", signature: "invalid")

      expect(result.status).to eq(:not_found)
      expect(result.body).to eq(error: "not_found")
    end

    it "returns not_found for paths the waiting node did not declare" do
      result = dispatch(http_method: "GET", path: "unknown")

      expect(result.status).to eq(:not_found)
      expect(result.body).to eq(error: "not_found")
    end
  end

  describe ".waiting_for?" do
    it "detects waiting executions handled by form restart webhooks" do
      expect(described_class.waiting_for?(execution, node_type: "form")).to eq(true)

      dispatch(http_method: "POST", params: { form_data: { "feedback" => "Approved" } })

      expect(described_class.waiting_for?(execution.reload, node_type: "form")).to eq(false)
    end
  end
end
