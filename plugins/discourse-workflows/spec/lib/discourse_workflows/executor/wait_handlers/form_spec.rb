# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::WaitHandlers::Form do
  fab!(:user)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :running,
      started_at: Time.current,
    )
  end

  describe "#pause!" do
    it "publishes waiting_for_form on MessageBus" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "action:form",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
      wait =
        DiscourseWorkflows::WaitForForm.new(
          form_fields: [{ "field_label" => "Name", "field_type" => "text" }],
          form_title: "User Info",
        )

      messages =
        MessageBus.track_publish(DiscourseWorkflows::Executor.form_channel(execution.id)) do
          handler.pause!(wait)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data).to eq({ status: "waiting_for_form" })
    end

    it "stores form_fields in waiting_config" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "action:form",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
      fields = [{ "field_label" => "Email", "field_type" => "text" }]
      wait =
        DiscourseWorkflows::WaitForForm.new(
          form_fields: fields,
          form_title: "Contact",
          form_description: "Fill out your info",
        )

      handler.pause!(wait)

      execution.reload
      expect(execution.status).to eq("waiting")
      expect(execution.waiting_config).to include(
        "wait_type" => described_class.wait_type,
        "resume_token" => "test-token",
        "form_title" => "Contact",
        "form_description" => "Fill out your info",
        "form_fields" => fields,
      )
    end
  end
end
