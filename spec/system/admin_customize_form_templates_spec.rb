# frozen_string_literal: true

describe "Admin Customize Form Templates", type: :system do
  let(:form_template_page) { PageObjects::Pages::FormTemplate.new }
  let(:ace_editor) { PageObjects::Components::AceEditor.new }

  fab!(:admin)
  fab!(:form_template)
  fab!(:category)

  before do
    SiteSetting.experimental_form_templates = true
    sign_in(admin)
  end

  describe "when visiting the page to customize form templates" do
    before { category.update!(form_template_ids: [form_template.id]) }

    it "should show the existing form templates in a table" do
      form_template_page.visit

      expect(form_template_page).to have_form_template_table
      expect(form_template_page).to have_form_template(form_template.name)
    end

    it "should show the categories the form template is used in" do
      form_template_page.visit

      expect(form_template_page).to have_form_template_table
      expect(form_template_page).to have_category_in_template_row(category.name)
    end

    it "should show the form template structure in a modal" do
      form_template_page.visit

      form_template_page.click_view_form_template
      expect(form_template_page).to have_template_structure("- type: input")
    end

    it "should show a preview of the template in a modal when toggling the preview" do
      form_template_page.visit

      form_template_page.click_view_form_template
      form_template_page.click_toggle_preview
      expect(form_template_page).to have_input_field("input")
    end

    context "when using the view template modal" do
      it "should navigate to the edit page when clicking the edit button" do
        form_template_page.visit
        form_template_page.click_view_form_template
        form_template_page.find(".d-modal__footer .btn-primary").click
        expect(page).to have_current_path("/admin/customize/form-templates/#{form_template.id}")
      end

      it "should delete the form template when clicking the delete button" do
        form_template_page.visit
        original_template_name = form_template.name
        form_template_page.click_view_form_template
        form_template_page.find(".d-modal__footer .btn-danger").click
        form_template_page.find(".dialog-footer .btn-primary").click

        expect(form_template_page).to have_no_form_template(original_template_name)
      end
    end
  end

  describe "when visiting the page to edit a form template" do
    it "should prefill form data" do
      visit("/admin/customize/form-templates/#{form_template.id}")
      expect(form_template_page).to have_name_value(form_template.name)
      expect(ace_editor).to have_content(form_template.template)
    end
  end

  def quick_insertion_test(field_type, content)
    form_template_page.visit_new
    form_template_page.type_in_template_name("New Template")
    form_template_page.click_quick_insert(field_type)
    expect(ace_editor).to have_text(content)
  end

  describe "when visiting the page to create a new form template" do
    it "should allow admin to create a new form template" do
      form_template_page.visit_new

      sample_name = "My First Template"
      sample_template = "- type: input\n  id: name"

      form_template_page.type_in_template_name(sample_name)
      ace_editor.type_input(sample_template)
      form_template_page.click_save_button
      expect(form_template_page).to have_form_template(sample_name)
    end

    it "should disable the save button until form is filled out" do
      form_template_page.visit_new
      expect(form_template_page).to have_save_button_with_state(disabled: true)
      form_template_page.type_in_template_name("New Template")
      expect(form_template_page).to have_save_button_with_state(disabled: true)
      ace_editor.type_input("- type: input")
      expect(form_template_page).to have_save_button_with_state(disabled: false)
    end

    it "should disable the preview button until form is filled out" do
      form_template_page.visit_new
      expect(form_template_page).to have_preview_button_with_state(disabled: true)
      form_template_page.type_in_template_name("New Template")
      expect(form_template_page).to have_preview_button_with_state(disabled: true)
      ace_editor.type_input("- type: input")
      expect(form_template_page).to have_preview_button_with_state(disabled: false)
    end

    it "should show validation options in a modal when clicking the validations button" do
      form_template_page.visit_new
      form_template_page.click_validations_button
      expect(form_template_page).to have_validations_modal
    end

    it "allows previewing, closing the modal, and then saving the template" do
      form_template_page.visit_new

      sample_name = "Preview Close Save Template"
      sample_template = "- type: input\n  id: name"

      form_template_page.type_in_template_name(sample_name)
      ace_editor.type_input(sample_template)

      form_template_page.click_preview_button
      expect(form_template_page).to have_preview_modal

      find(".modal-close").click
      expect(form_template_page).to have_no_preview_modal

      form_template_page.click_save_button
      expect(form_template_page).to have_form_template(sample_name)
    end

    it "should show a preview of the template in a modal when clicking the preview button" do
      form_template_page.visit_new
      form_template_page.type_in_template_name("New Template")
      ace_editor.type_input("- type: input\n  id: name")
      form_template_page.click_preview_button

      expect(form_template_page).to have_preview_modal
      expect(form_template_page).to have_input_field("input")
    end

    it "should render all the input field types in the preview" do
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      tag3 = Fabricate(:tag)
      tag_group = Fabricate(:tag_group, tags: [tag1, tag2, tag3])
      form_template_page.visit_new
      form_template_page.type_in_template_name("New Template")
      template = <<~YAML
        - type: input
          id: i1
        - type: textarea
          id: t2
        - type: checkbox
          id: checkbox
        - type: dropdown
          id: dropdown
        - type: upload
          id: upload
        - type: multi-select
          id: multi-select
        - type: tag-chooser
          id: tag-chooser
          tag_group: "#{tag_group.name}"
      YAML

      ace_editor.type_input(template)
      form_template_page.click_preview_button

      YAML
        .safe_load(template)
        .each do |field|
          expect(form_template_page).to have_input_field_with_name(field["type"], field["id"])
        end

      tag_group.tags.each { |tag| expect(form_template_page).to have_tag_chooser_tag(tag) }
    end

    it "should allow quick insertion of checkbox field" do
      quick_insertion_test(
        "checkbox",
        '- type: checkbox
  id: enter-id-here
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
  id: enter-id-here
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
  id: enter-id-here
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
  id: enter-id-here
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

    it "should allow quick insertion of upload field" do
      quick_insertion_test(
        "upload",
        '- type: upload
  id: enter-id-here
  attributes:
    file_types: ".jpg, .png, .gif"
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
  id: enter-id-here
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
