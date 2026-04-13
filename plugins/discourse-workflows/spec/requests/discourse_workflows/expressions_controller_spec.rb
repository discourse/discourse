# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionsController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "POST /admin/plugins/discourse-workflows/expressions/evaluate" do
    let(:endpoint) { "/admin/plugins/discourse-workflows/expressions/evaluate.json" }

    it "evaluates a plain text template" do
      post endpoint, params: { template: "Hello world" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"]).to contain_exactly(
        { "kind" => "plaintext", "text" => "Hello world" },
      )
    end

    it "evaluates a template with expressions" do
      post endpoint, params: { template: "Hello {{ $current_user.username }}!" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"].length).to eq(3)
      expect(json["segments"][0]).to eq({ "kind" => "plaintext", "text" => "Hello " })
      expect(json["segments"][1]["kind"]).to eq("resolved")
      expect(json["segments"][1]["state"]).to eq("valid")
      expect(json["segments"][1]["text"]).to eq(admin.username)
      expect(json["segments"][2]).to eq({ "kind" => "plaintext", "text" => "!" })
    end

    it "marks undefined references" do
      post endpoint, params: { template: "{{ undefined_var.missing }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["kind"]).to eq("resolved")
      expect(json["segments"][0]["state"]).to eq("undefined")
    end

    it "marks syntax errors as invalid" do
      post endpoint, params: { template: "{{ if( }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("invalid")
    end

    it "detects uncalled functions as warnings" do
      post endpoint, params: { template: "{{ $current_user.username.includes }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("warning")
    end

    it "uses execution data for $json when workflow_id is provided" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      execution = DiscourseWorkflows::Execution.create!(workflow: workflow, status: :success)
      DiscourseWorkflows::ExecutionData.create!(
        execution: execution,
        data: {
          entries: {
            "Topic created" => [
              {
                "status" => "success",
                "node_type" => "trigger:topic_created",
                "output_items" => [{ "json" => { "title" => "Test Topic" } }],
              },
            ],
          },
        }.to_json,
      )

      post endpoint, params: { template: "{{ $json.title }}", workflow_id: workflow.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["text"]).to eq("Test Topic")
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "resolves $execution metadata when workflow_id is provided" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, name: "My Workflow")

      post endpoint,
           params: {
             template: "{{ $execution.workflow_name }}",
             workflow_id: workflow.id,
           }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["text"]).to eq("My Workflow")
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "resolves $json fields from trigger schema without past execution data" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [{ "id" => "1", "type" => "trigger:topic_created", "name" => "Topic created" }],
        )

      post endpoint, params: { template: "{{ $json.topic.title }}", workflow_id: workflow.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "marks unknown fields as undefined with schema" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [{ "id" => "1", "type" => "trigger:topic_created", "name" => "Topic created" }],
        )

      post endpoint, params: { template: "{{ $json.nonexistent }}", workflow_id: workflow.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("undefined")
    end

    it "evaluates multiline expressions" do
      template = "{{ $current_user\n  .username }}"
      post endpoint, params: { template: }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("valid")
      expect(json["segments"][0]["text"]).to eq(admin.username)
    end

    it "marks trailing dot access as invalid" do
      post endpoint, params: { template: "{{ $vars. }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["kind"]).to eq("resolved")
      expect(json["segments"][0]["state"]).to eq("invalid")
    end

    it "resolves $vars" do
      Fabricate(:discourse_workflows_variable, key: "API_KEY", value: "secret123")
      post endpoint, params: { template: "{{ $vars.API_KEY }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["text"]).to eq("secret123")
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "resolves $site_settings" do
      post endpoint, params: { template: "{{ $site_settings.title }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["text"]).to eq(SiteSetting.title)
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "handles multiple expressions with mixed validity" do
      post endpoint, params: { template: "{{ $current_user.username }} {{ bad. }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      valid_seg = json["segments"].find { |s| s["state"] == "valid" }
      invalid_seg = json["segments"].find { |s| s["state"] == "invalid" }
      expect(valid_seg["text"]).to eq(admin.username)
      expect(invalid_seg).to be_present
    end

    it "handles unclosed {{ as plaintext" do
      post endpoint, params: { template: "Hello {{ $json.title" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      segments = json["segments"]
      expect(segments.last["kind"]).to eq("plaintext")
      expect(segments.last["text"]).to include("{{")
    end

    it "formats array results as JSON" do
      post endpoint, params: { template: "{{ [1, 2, 3] }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["text"]).to eq("1, 2, 3")
      expect(json["segments"][0]["state"]).to eq("valid")
    end

    it "retries bare object literals wrapped in parens on SyntaxError" do
      post endpoint, params: { template: "{{ {a: 1, b: 2} }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("valid")
      expect(json["segments"][0]["text"]).to eq("a, 1, b, 2")
    end

    it "handles adjacent expressions with no separator" do
      post endpoint, params: { template: "{{ 1 }}{{ 2 }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      resolved_segments = json["segments"].select { |s| s["kind"] == "resolved" }
      expect(resolved_segments.length).to eq(2)
      expect(resolved_segments[0]["text"]).to eq("1")
      expect(resolved_segments[1]["text"]).to eq("2")
    end

    it "handles nested braces inside expressions" do
      post endpoint, params: { template: "{{ [1,2].filter(x => x > 1) }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("valid")
      expect(json["segments"][0]["text"]).to eq("2")
    end

    it "resolves node references via $()" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
      execution = DiscourseWorkflows::Execution.create!(workflow: workflow, status: :success)
      DiscourseWorkflows::ExecutionData.create!(
        execution: execution,
        data: {
          entries: {
            "Fetch data" => [
              {
                "status" => "success",
                "node_type" => "action:http_request",
                "output_items" => [{ "json" => { "name" => "Alice" } }],
              },
            ],
          },
        }.to_json,
      )

      post endpoint,
           params: {
             template: "{{ $('Fetch data').item.json.name }}",
             workflow_id: workflow.id,
           }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("valid")
      expect(json["segments"][0]["text"]).to eq("Alice")
    end

    it "marks chaining off missing node refs as undefined" do
      post endpoint, params: { template: "{{ $('Missing').item.item.item }}" }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["segments"][0]["state"]).to eq("undefined")
    end

    it "is rate limited" do
      RateLimiter.enable
      freeze_time

      30.times do
        post endpoint, params: { template: "test" }
        expect(response.status).to eq(200)
      end

      post endpoint, params: { template: "test" }
      expect(response.status).to eq(429)
    end

    it "requires the template parameter" do
      post endpoint, params: {}
      expect(response.status).to eq(400)
    end

    it "requires admin access" do
      sign_in(Fabricate(:user))
      post endpoint, params: { template: "test" }
      expect(response.status).to eq(404)
    end
  end
end
