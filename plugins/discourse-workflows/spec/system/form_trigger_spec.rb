# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Form Trigger" do
  FORM_UUID = "a1b2c3d4-e5f6-7890-abcd-ef0123456789"

  let(:form_trigger_page) { PageObjects::Pages::DiscourseWorkflows::FormTrigger.new }

  fab!(:workflow) do
    Fabricate(
      :discourse_workflows_workflow,
      published: true,
      nodes: [
        {
          "id" => "trigger-1",
          "type" => "trigger:form",
          "typeVersion" => "1.0",
          "name" => "Form Trigger",
          "position" => {
            "x" => 0,
            "y" => 0,
          },
          "parameters" => {
            "form_title" => "Contact Us",
            "form_fields" => [
              { "field_label" => "Your name", "field_type" => "text", "required" => true },
            ],
            "response_mode" => "on_received",
            "authentication" => "none",
          },
          "credentials" => {
          },
          "webhookId" => FORM_UUID,
        },
      ],
      connections: {
      },
    )
  end

  before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

  it "renders the public form" do
    form_trigger_page.visit(FORM_UUID)

    expect(form_trigger_page).to have_workflows_form
    expect(form_trigger_page).to have_form_title("Contact Us")
    expect(form_trigger_page).to have_form_field("your_name")
  end

  it "submits the form and shows completion" do
    form_trigger_page.visit(FORM_UUID)

    form_trigger_page.fill_field("your_name", "Alice").submit

    expect(form_trigger_page).to have_completion
  end
end
