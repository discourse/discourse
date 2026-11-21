# frozen_string_literal: true

RSpec.describe "Editing workflow form fields" do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "start",
               "trigger:form",
               configuration: {
                 "uuid" => SecureRandom.uuid,
                 "form_fields" => {
                   "values" => [{ "field_type" => "text", "field_label" => "Attendee" }],
                 },
               }
        g.node "details",
               "action:form",
               configuration: {
                 "page_type" => "page",
                 "form_title" => "Meal preferences",
                 "form_fields" => [
                   {
                     "field_type" => "text",
                     "field_label" => "Guest",
                     "default_value" => "={{ $json.attendee }}",
                   },
                   {
                     "field_type" => "dropdown",
                     "field_label" => "Meal",
                     "field_name" => "meal_code",
                     "options" => {
                       "values" => [{ "value" => "Standard" }, { "value" => "Vegetarian" }],
                     },
                     "required" => true,
                   },
                   {
                     "field_type" => "hiddenField",
                     "field_label" => "Source",
                     "field_name" => "source_id",
                     "field_value" => "host",
                   },
                 ],
               }
        g.node "finish",
               "action:form",
               configuration: {
                 "page_type" => "completion",
                 "completion_title" => "={{ $json.meal_code }}",
                 "completion_message" => "={{ $json.guest + ' from ' + $json.source_id }}",
               }
        g.chain "start", "details", "finish"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  let(:editor) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }
  let(:form) { PageObjects::Pages::DiscourseWorkflows::FormTrigger.new }

  before { sign_in(admin) }

  def submit_meal_preferences(expected_choices)
    form.visit(workflow.find_node("start").fetch("webhookId"))
    form.fill_field("attendee", "Riley").submit
    expect(form).to have_form_title("Meal preferences")
    expect(form).to have_choices("meal_code", expected_choices)
    form.choose("meal_code", "Vegetarian").submit
    expect(form).to have_completion_text("Vegetarian")
    expect(form).to have_completion_text("Riley from host")
  end

  it "lets an admin mark a field required or optional from its badge or Attributes menu" do
    editor.visit_node(workflow, "start")
    expect(editor).to have_requirement_badge("Optional")

    editor.press_requirement_badge("Attendee", :space)
    expect(editor).to have_requirement_badge("Required")
    expect(editor).to have_no_form_field_requirement_toggle
    expect(editor).to have_saved_node_configuration

    page.refresh
    expect(editor).to have_requirement_badge("Required")
    editor.set_form_field_required("Attendee", required: false)
    expect(editor).to have_requirement_badge("Optional")
    expect(editor).to have_saved_node_configuration

    page.refresh
    expect(editor).to have_requirement_badge("Optional")
    editor.press_requirement_badge("Attendee", :enter)
    expect(editor).to have_requirement_badge("Required")
  end

  it "lets an admin reorder a saved form and use its existing answers in downstream expressions" do
    submit_meal_preferences(%w[Standard Vegetarian])

    editor.visit_node(workflow, "details")
    expect(editor).to have_first_form_field("Guest")
    expect(editor).to have_type_before_label
    editor.move_form_field_up("Meal")
    expect(editor).to have_saved_node_configuration
    editor.move_last_choice_up
    expect(editor).to have_saved_node_configuration

    page.refresh
    expect(editor).to have_first_form_field("Meal")
    editor.close_node_configurator.click_publish
    expect(editor).to have_no_publish_banner

    submit_meal_preferences(%w[Vegetarian Standard])
  end
end
