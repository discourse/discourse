# frozen_string_literal: true

describe "Admin Customize Form Templates", type: :system, js: true do
  let(:form_template_page) { PageObjects::Pages::FormTemplate.new }
  let(:ace_editor) { PageObjects::Components::AceEditor.new }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:form_template) { Fabricate(:form_template) }

  before do
    SiteSetting.experimental_form_templates = true
    sign_in(admin)
  end

  describe "when visiting the page to customize form templates" do
    it "should show the existing form templates in a table" do
      visit("/admin/customize/form-templates")
      expect(form_template_page).to have_form_template_table
      expect(form_template_page).to have_form_template(form_template.name)
    end

    it "should show the form template structure in a modal" do
      visit("/admin/customize/form-templates")
      form_template_page.click_view_form_template
      expect(form_template_page).to have_template_structure("some yaml template: value")
    end
  end

  describe "when visiting the page to edit a form template" do
    it "should prefill form data" do
      visit("/admin/customize/form-templates/#{form_template.id}")
      expect(form_template_page).to have_name_value(form_template.name)
      # difficult to test the ace editor content (todo later)
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
      sample_template = "test: true"

      form_template_page.type_in_template_name(sample_name)
      ace_editor.type_input(sample_template)
      form_template_page.click_save_button
      expect(form_template_page).to have_form_template(sample_name)
    end

    it "should allow quick insertion of checkbox field" do
      quick_insertion_test(
        "checkbox",
        '- type: checkbox
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    label: "Enter question here"
    description: "Enter description here"
    validations:
      required: true',
      )
    end

    it "should allow quick insertion of short answer field" do
      quick_insertion_test(
        "input",
        '- type: input
  attributes:
    label: "Enter input label here"
    description: "Enter input description here"
    placeholder: "Enter input placeholder here"
    validations:
      required: true',
      )
    end

    it "should allow quick insertion of long answer field" do
      quick_insertion_test(
        "textarea",
        '- type: textarea
  attributes:
    label: "Enter textarea label here"
    description: "Enter textarea description here"
    placeholder: "Enter textarea placeholder here"
    validations:
      required: true',
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
    label: "Enter dropdown label here"
    description: "Enter dropdown description here"
    validations:
      required: true',
      )
    end

    it "should allow quick insertion of upload field" do
      quick_insertion_test(
        "upload",
        '- type: upload
  attributes:
    file_types: "jpg, png, gif"
    label: "Enter upload label here"
    description: "Enter upload description here"',
      )
    end

    it "should allow quick insertion of multiple choice field" do
      quick_insertion_test(
        "multiselect",
        '- type: multiple_choice
  choices:
    - "Option 1"
    - "Option 2"
    - "Option 3"
  attributes:
    label: "Enter multiple choice label here"
    description: "Enter multiple choice description here"
    validations:
      required: true',
      )
    end
  end
end
