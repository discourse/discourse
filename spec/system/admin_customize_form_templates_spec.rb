# frozen_string_literal: true

describe "Admin Customize Form Templates", type: :system, js: true do
  let(:form_template_page) { PageObjects::Pages::FormTemplate.new }
  let(:ace_editor) { PageObjects::Components::AceEditor.new }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:form_template) { Fabricate(:form_template) }
  fab!(:category) do
    Fabricate(:category, name: "Cool Category", slug: "cool-cat", topic_count: 3234)
  end

  before do
    SiteSetting.experimental_form_templates = true
    sign_in(admin)
  end

  describe "when visiting the page to customize form templates" do
    before { category.update(form_template_ids: [form_template.id]) }

    it "should show the existing form templates in a table" do
      visit("/admin/customize/form-templates")
      expect(form_template_page).to have_form_template_table
      expect(form_template_page).to have_form_template(form_template.name)
    end

    it "should show the categories the form template is used in" do
      visit("/admin/customize/form-templates")
      expect(form_template_page).to have_form_template_table
      expect(form_template_page).to have_category_in_template_row(category.name)
    end

    it "should show the form template structure in a modal" do
      visit("/admin/customize/form-templates")
      form_template_page.click_view_form_template
      expect(form_template_page).to have_template_structure("- type: input")
    end

    it "should show a preview of the template in a modal when toggling the preview" do
      visit("/admin/customize/form-templates")
      form_template_page.click_view_form_template
      form_template_page.click_toggle_preview
      expect(form_template_page).to have_input_field("input")
    end
  end

  describe "when visiting the page to edit a form template" do
    it "should prefill form data" do
      visit("/admin/customize/form-templates/#{form_template.id}")
      expect(form_template_page).to have_name_value(form_template.name)
      # TODO(@keegan) difficult to test the ace editor content, todo later
    end
  end

  def quick_insertion_test(field_type, content)
    visit("/admin/customize/form-templates/new")
    form_template_page.type_in_template_name("New Template")
    form_template_page.click_quick_insert(field_type)
    expect(ace_editor).to have_text(content)
  end

  describe "when visiting the page to create a new form template" do
    it "should allow admin to create a new form template" do
      visit("/admin/customize/form-templates/new")

      sample_name = "My First Template"
      sample_template = "- type: input"

      form_template_page.type_in_template_name(sample_name)
      ace_editor.type_input(sample_template)
      form_template_page.click_save_button
      expect(form_template_page).to have_form_template(sample_name)
    end

    it "should disable the save button until form is filled out" do
      visit("/admin/customize/form-templates/new")
      expect(form_template_page).to have_save_button_with_state(true)
      form_template_page.type_in_template_name("New Template")
      expect(form_template_page).to have_save_button_with_state(true)
      ace_editor.type_input("- type: input")
      expect(form_template_page).to have_save_button_with_state(false)
    end

    it "should disable the preview button until form is filled out" do
      visit("/admin/customize/form-templates/new")
      expect(form_template_page).to have_preview_button_with_state(true)
      form_template_page.type_in_template_name("New Template")
      expect(form_template_page).to have_preview_button_with_state(true)
      ace_editor.type_input("- type: input")
      expect(form_template_page).to have_preview_button_with_state(false)
    end

    it "should show validation options in a modal when clicking the validations button" do
      visit("/admin/customize/form-templates/new")
      form_template_page.click_validations_button
      expect(form_template_page).to have_validations_modal
    end

    it "should show a preview of the template in a modal when clicking the preview button" do
      visit("/admin/customize/form-templates/new")
      form_template_page.type_in_template_name("New Template")
      ace_editor.type_input("- type: input")
      form_template_page.click_preview_button
      expect(form_template_page).to have_preview_modal
      expect(form_template_page).to have_input_field("input")
    end

    it "should render all the input field types in the preview" do
      visit("/admin/customize/form-templates/new")
      form_template_page.type_in_template_name("New Template")
      ace_editor.type_input(
        "- type: input\n- type: textarea\n- type: checkbox\n- type: dropdown\n- type: upload\n- type: multi-select",
      )
      form_template_page.click_preview_button
      expect(form_template_page).to have_input_field("input")
      expect(form_template_page).to have_input_field("textarea")
      expect(form_template_page).to have_input_field("checkbox")
      expect(form_template_page).to have_input_field("dropdown")
      expect(form_template_page).to have_input_field("upload")
      expect(form_template_page).to have_input_field("multi-select")
    end

    it "should allow quick insertion of checkbox field" do
      quick_insertion_test(
        "checkbox",
        '- type: checkbox
  attributes:
    label: "Enter label here"
  validations:
    # enter validations here',
      )
    end

    it "should allow quick insertion of short answer field" do
      quick_insertion_test(
        "input",
        '- type: input
  attributes:
    label: "Enter label here"
    placeholder: "Enter placeholder here"
  validations:
    # enter validations here',
      )
    end

    it "should allow quick insertion of long answer field" do
      quick_insertion_test(
        "textarea",
        '- type: textarea
  attributes:
    label: "Enter label here"
    placeholder: "Enter placeholder here"
  validations:
    # enter validations here',
      )
    end

    it "should allow quick insertion of dropdown field" do
      quick_insertion_test(
        "dropdown",
        '- type: dropdown
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    none_label: "Select an item"
    label: "Enter label here"
    filterable: false
  validations:
    # enter validations here',
      )
    end

    it "should allow quick insertion of upload field" do
      quick_insertion_test(
        "upload",
        '- type: upload
  attributes:
    file_types: "jpg, png, gif"
    allow_multiple: false
    label: "Enter label here"
  validations:
    # enter validations here',
      )
    end

    it "should allow quick insertion of multiple choice field" do
      quick_insertion_test(
        "multiselect",
        '- type: multi-select
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    none_label: "Select an item"
    label: "Enter label here"
  validations:
    # enter validations here',
      )
    end
  end
end
