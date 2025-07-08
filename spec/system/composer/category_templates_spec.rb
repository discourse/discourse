# frozen_string_literal: true

describe "Composer Form Templates", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:form_template_1) do
    Fabricate(
      :form_template,
      name: "Bug Reports",
      template:
        "- type: input
  id: full-name
  attributes:
    label: What is your full name?
    placeholder: John Doe
  validations:
    required: true",
    )
  end
  fab!(:form_template_2) do
    Fabricate(:form_template, name: "Feature Request", template: "- type: checkbox\n  id: check")
  end
  fab!(:form_template_3) do
    Fabricate(:form_template, name: "Awesome Possum", template: "- type: dropdown\n  id: dropdown")
  end
  fab!(:form_template_4) do
    Fabricate(:form_template, name: "Biography", template: "- type: textarea\n  id: bio")
  end
  fab!(:form_template_5) do
    Fabricate(
      :form_template,
      name: "Medication",
      template:
        %Q(
        - type: input
          id: full-name
          attributes:
            label: "What is your name?"
            placeholder: "John Smith"
          validations:
            required: false
        - type: upload
          id: prescription
          attributes:
            file_types: ".jpg, .png"
            allow_multiple: false
            label: "Upload your prescription"
            validations:
            required: true
        - type: upload
          id: additional-docs
          attributes:
            file_types: ".jpg, .png, .pdf, .mp3, .mp4"
            allow_multiple: true
            label: "Any additional docs"
            validations:
            required: false"),
    )
  end
  fab!(:form_template_6) do
    Fabricate(
      :form_template,
      name: "Descriptions",
      template:
        %Q(
        - type: input
          id: full-name
          attributes:
            label: "Full name"
            description: "What is your full name?"
            placeholder: "John Smith"
          validations:
            required: false
        - type: upload
          id: prescription
          attributes:
            file_types: ".jpg, .png"
            allow_multiple: false
            label: "Prescription"
            description: "Upload your prescription"
          validations:
            required: true"),
    )
  end

  fab!(:form_template_7) do
    Fabricate(
      :form_template,
      name: "Preview Test",
      template:
        %Q(
        - type: checkbox
          id: 1
          attributes:
            label: "checkbox"
        - type: input
          id: 2
          attributes:
            label: "input"
            placeholder: "Enter placeholder here"
        - type: textarea
          id: 3
          attributes:
            label: "textarea"
            placeholder: "Enter placeholder here"
        - type: dropdown
          id: 4
          choices:
            - "Option 1"
            - "Option 2"
            - "Option 3"
          attributes:
            none_label: "Select an item"
            label: "dropdown"
        - type: upload
          id: 5
          attributes:
            file_types: ".jpg, .png, .gif"
            allow_multiple: false
            label: "upload"
        - type: multi-select
          id: 6
          choices:
            - "Option 4"
            - "Option 5"
            - "Option 6"
          attributes:
            none_label: "Select an item"
            label: "multi-select"
          ),
    )
  end
  fab!(:category_with_template_1) do
    Fabricate(
      :category,
      name: "Reports",
      slug: "reports",
      topic_count: 2,
      form_template_ids: [form_template_1.id],
    )
  end
  fab!(:category_with_template_2) do
    Fabricate(
      :category,
      name: "Features",
      slug: "features",
      topic_count: 3,
      form_template_ids: [form_template_2.id],
    )
  end
  fab!(:category_with_template_7) do
    Fabricate(
      :category,
      name: "Preview Test",
      slug: "preview_test",
      topic_count: 2,
      form_template_ids: [form_template_7.id],
    )
  end
  fab!(:category_with_multiple_templates_1) do
    Fabricate(
      :category,
      name: "Multiple",
      slug: "multiple",
      topic_count: 10,
      form_template_ids: [form_template_1.id, form_template_2.id],
    )
  end
  fab!(:category_with_multiple_templates_2) do
    Fabricate(
      :category,
      name: "More Stuff",
      slug: "more-stuff",
      topic_count: 10,
      form_template_ids: [form_template_3.id, form_template_4.id],
    )
  end
  fab!(:category_with_upload_template) do
    Fabricate(
      :category,
      name: "Medical",
      slug: "medical",
      topic_count: 2,
      form_template_ids: [form_template_5.id],
    )
  end
  fab!(:category_no_template) do
    Fabricate(:category, name: "Staff", slug: "staff", topic_count: 2, form_template_ids: [])
  end
  fab!(:category_topic_template) do
    Fabricate(
      :category,
      name: "Random",
      slug: "random",
      topic_count: 5,
      form_template_ids: [],
      topic_template: "Testing",
    )
  end
  fab!(:category_with_template_6) do
    Fabricate(
      :category,
      name: "Descriptions",
      slug: "descriptions",
      topic_count: 2,
      form_template_ids: [form_template_6.id],
    )
  end

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:form_template_chooser) { PageObjects::Components::SelectKit.new(".form-template-chooser") }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.experimental_form_templates = true
    SiteSetting.authorized_extensions = "*"
    sign_in user
  end

  describe "discard draft modal" do
    it "does not show the modal if there is no draft on a topic without a template" do
      category_page.visit(category_no_template)
      category_page.new_topic_button.click
      composer.close
      expect(composer).to be_closed
    end

    it "shows the modal if there is a draft on a topic without a template" do
      category_page.visit(category_no_template)
      category_page.new_topic_button.click
      composer.fill_content("abc")
      composer.close
      expect(composer).to be_opened
      expect(composer).to have_discard_draft_modal
    end

    it "does not show the modal if there is no draft on a topic with a topic template" do
      category_page.visit(category_topic_template)
      category_page.new_topic_button.click
      composer.close
      expect(composer).to be_closed
    end

    it "shows the modal if there is a draft on a topic with a topic template" do
      category_page.visit(category_topic_template)
      category_page.new_topic_button.click
      composer.append_content(" some more content")
      composer.close
      expect(composer).to be_opened
      expect(composer).to have_discard_draft_modal
    end

    it "does not show the modal if on a topic with a form template" do
      category_page.visit(category_with_template_1)
      category_page.new_topic_button.click
      composer.close
      expect(composer).to be_closed
    end

    context "when the default template has a topic template" do
      SiteSetting.default_composer_category =
        (
          if SiteSetting.general_category_id != -1
            SiteSetting.general_category_id
          else
            SiteSetting.uncategorized_category_id
          end
        )
      let(:default_category) { Category.find(SiteSetting.default_composer_category) }

      before { default_category.update!(topic_template: "Testing") }

      it "does not show the modal if there is no draft" do
        category_page.visit(default_category)
        category_page.new_topic_button.click
        composer.close
        expect(composer).to be_closed
      end

      it "shows the modal if there is a draft" do
        category_page.visit(default_category)
        category_page.new_topic_button.click
        composer.append_content(" some more content")
        composer.close
        expect(composer).to be_opened
        expect(composer).to have_discard_draft_modal
      end
    end
  end

  it "shows a textarea when no form template is assigned to the category" do
    category_page.visit(category_no_template)
    category_page.new_topic_button.click
    expect(composer).to have_composer_input
  end

  it "shows a textarea filled in with topic template when a topic template is assigned to the category" do
    category_page.visit(category_topic_template)
    category_page.new_topic_button.click
    expect(composer).to have_composer_input
    expect(composer).to have_content(category_topic_template.topic_template)
  end

  it "shows a form when a form template is assigned to the category" do
    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    expect(composer).to have_no_composer_input
    expect(composer).to have_form_template
    expect(composer).to have_form_template_field("input")
  end

  it "shows the preview when a category without a form template is selected" do
    category_page.visit(category_no_template)
    category_page.new_topic_button.click
    expect(composer).to have_composer_preview
    expect(composer).to have_composer_preview_toggle
  end

  it "hides the preview when a category with a form template is selected" do
    SiteSetting.show_preview_for_form_templates = false
    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    expect(composer).to have_no_composer_preview
    expect(composer).to have_no_composer_preview_toggle
  end

  it "shows the preview when a category with a form template is selected" do
    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    expect(composer).to have_composer_preview
    expect(composer).to have_composer_preview_toggle
  end

  it "shows the correct template when switching categories" do
    category_page.visit(category_no_template)
    category_page.new_topic_button.click
    # first category has no template
    expect(composer).to have_composer_input
    # switch to category with topic template
    composer.switch_category(category_topic_template.name)
    expect(composer).to have_composer_input
    expect(composer).to have_content(category_topic_template.topic_template)
    # switch to category with form template
    composer.switch_category(category_with_template_1.name)
    expect(composer).to have_form_template
    expect(composer).to have_form_template_field("input")
    # switch to category with a different form template
    composer.switch_category(category_with_template_2.name)
    expect(composer).to have_form_template
    expect(composer).to have_form_template_field("checkbox")
  end

  it "does not show form template chooser when a category only has form template" do
    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    expect(composer).to have_no_form_template_chooser
  end

  it "shows form template chooser when a category has multiple form templates" do
    category_page.visit(category_with_multiple_templates_1)
    category_page.new_topic_button.click
    expect(composer).to have_form_template_chooser
  end

  it "updates the form template when a different template is selected" do
    category_page.visit(category_with_multiple_templates_1)
    category_page.new_topic_button.click
    expect(composer).to have_form_template_field("input")
    form_template_chooser.select_row_by_name(form_template_2.name)
    expect(composer).to have_form_template_field("checkbox")
  end

  it "shows the correct template options when switching categories" do
    category_page.visit(category_with_multiple_templates_1)
    category_page.new_topic_button.click
    expect(composer).to have_form_template_chooser
    form_template_chooser.expand
    expect(form_template_chooser).to have_selected_choice_name(form_template_1.name)
    expect(form_template_chooser).to have_option_name(form_template_2.name)
    composer.switch_category(category_with_multiple_templates_2.name)
    form_template_chooser.expand
    expect(form_template_chooser).to have_selected_choice_name(form_template_3.name)
    expect(form_template_chooser).to have_option_name(form_template_4.name)
  end

  it "shows the correct template name in the dropdown header after switching templates" do
    category_page.visit(category_with_multiple_templates_1)
    category_page.new_topic_button.click
    expect(form_template_chooser).to have_selected_name(form_template_1.name)
    form_template_chooser.select_row_by_name(form_template_2.name)
    expect(form_template_chooser).to have_selected_name(form_template_2.name)
  end

  it "forms a post when template fields are filled in" do
    topic_title = "A topic about Batman"

    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "Bruce Wayne")
    composer.create

    expect(topic_page).to have_topic_title(topic_title)
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked p")).to have_content(
      "Bruce Wayne",
    )
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked h3")).to have_content(
      "What is your full name?",
    )
  end

  it "creates a post with an upload field" do
    topic_title = "Bruce Wayne's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/logo.png",
                make_visible: true
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "Bruce Wayne")
    composer.create

    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css(
      "img[alt='logo.png']",
    )
  end

  it "doesn't allow uploading an invalid file type" do
    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/animated.gif",
                make_visible: true
    expect(find("#dialog-holder .dialog-body p", visible: :all)).to have_content(
      I18n.t("js.pick_files_button.unsupported_file_picked", { types: ".jpg, .png" }),
    )
    expect(page).to have_no_css(".form-template-field__uploaded-files")
  end

  it "creates a post with multiple uploads" do
    topic_title = "Peter Parker's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/logo.png",
                make_visible: true
    attach_file "additional-docs-uploader",
                [
                  "#{Rails.root}/spec/fixtures/media/small.mp3",
                  "#{Rails.root}/spec/fixtures/media/small.mp4",
                  "#{Rails.root}/spec/fixtures/pdf/small.pdf",
                ],
                make_visible: true
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "Peter Parker}")
    composer.create

    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css(
      "img[alt='logo.png']",
    )
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css("a.attachment")
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css("audio")
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css(
      ".video-placeholder-container",
    )
  end

  it "overrides uploaded file if allow_multiple false" do
    topic_title = "Peter Parker's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/logo.png",
                make_visible: true
    composer.fill_title(topic_title)
    attach_file "prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/fake.jpg",
                make_visible: true

    expect(find(".form-template-field__uploaded-files")).to have_css("li", count: 1)
  end

  it "shows labels and descriptions when a form template is assigned to the category" do
    category_page.visit(category_with_template_6)
    category_page.new_topic_button.click
    expect(composer).to have_no_composer_input
    expect(composer).to have_form_template

    expect(composer).to have_form_template_field("input")
    expect(composer).to have_form_template_field_label("Full name")
    expect(composer).to have_form_template_field_description("What is your full name?")

    expect(composer).to have_form_template_field("upload")
    expect(composer).to have_form_template_field_label("Prescription")
    expect(composer).to have_form_template_field_description("Upload your prescription")
  end

  it "shows preview of the form correctly for all input types" do
    topic_title = "A topic about Batman"
    category_page.visit(category_with_template_7)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "Peter Parker")

    expect(find(".d-editor-preview")).to have_content("Peter Parker")

    find(:select, "4").find(:option, "Option 2").select_option
    find(:select, "4").find(:option, "Option 1").select_option

    expect(find(".d-editor-preview")).to have_content("Option 1")

    find(:select, "6").find(:option, "Option 4").select_option

    expect(find(".d-editor-preview")).to have_content("Option 4")

    message = "This is a test message!"
    find("textarea").fill_in(with: message)

    expect(find(".d-editor-preview")).to have_content(message)

    attach_file("5-uploader", "#{Rails.root}/spec/fixtures/images/logo.png", make_visible: true)
    expect(find(".d-editor-preview")).to have_css("img")
  end

  context "when using tagchooser" do
    fab!(:tag1) { Fabricate(:tag, description: "Tag 1 custom Translation") }
    fab!(:tag2) { Fabricate(:tag, description: "Tag 2 custom Translation") }
    fab!(:tag3) { Fabricate(:tag) }
    fab!(:tag4) { Fabricate(:tag) }

    fab!(:tag_group1) { Fabricate(:tag_group, name: "tag_group1", tags: [tag1, tag3]) }
    fab!(:tag_group2) { Fabricate(:tag_group, name: "tag_group2", tags: [tag2, tag4]) }

    fab!(:tag_groups_form_template) do
      Fabricate(
        :form_template,
        name: "TagGroups",
        template:
          %Q(
            - type: tag-chooser
              id: 1
              attributes:
                label: "Full name"
                description: "What is your full name?"
                multiple: true
              tag_group: "tag_group1"  # Replace with actual value if needed
              validations:
                required: false

            - type: tag-chooser
              id: 2
              attributes:
                label: "Prescription"
                description: "Upload your prescription"
                multiple: false
              tag_group: "tag_group2"
              validations:
                required: true),
      )
    end

    fab!(:category_with_tagchooser_template) do
      Fabricate(
        :category,
        name: "tagtest",
        slug: "tagtest",
        topic_count: 2,
        form_template_ids: [tag_groups_form_template.id],
      )
    end

    it "shows the correct tag group descriptions" do
      category_page.visit(category_with_tagchooser_template)
      category_page.new_topic_button.click

      expect(find("[name='1']")).to have_content("#{tag3.name.upcase}")
      expect(find("[name='2']")).to have_content("#{tag4.name.upcase}")

      find(:select, "1").find(:option, tag1.description).select_option
      find(:select, "2").find(:option, tag2.description).select_option

      expect(page).to have_select("1", selected: tag1.description)
      expect(page).to have_select("2", selected: tag2.description)

      mini_tag_chooser = PageObjects::Components::SelectKit.new(".mini-tag-chooser")
      expect(mini_tag_chooser).to have_selected_name("#{tag1.name},#{tag2.name}")
    end

    it "updates form when selecting tags in the composer" do
      category_page.visit(category_with_tagchooser_template)
      category_page.new_topic_button.click
      mini_tag_chooser = PageObjects::Components::SelectKit.new(".mini-tag-chooser")
      mini_tag_chooser.select_row_by_name(tag1.name)

      expect(page).to have_select("1", selected: tag1.description)

      mini_tag_chooser.unselect_by_name(tag1.name)

      expect(mini_tag_chooser).to have_no_selection
    end
  end
end
