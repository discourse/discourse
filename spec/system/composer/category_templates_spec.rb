# frozen_string_literal: true

describe "Composer Form Templates", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:form_template_1) do
    Fabricate(
      :form_template,
      name: "Bug Reports",
      template:
        "- type: input
  attributes:
    label: What is your full name?
    placeholder: John Doe
  validations:
    required: true",
    )
  end
  fab!(:form_template_2) do
    Fabricate(:form_template, name: "Feature Request", template: "- type: checkbox")
  end
  fab!(:form_template_3) do
    Fabricate(:form_template, name: "Awesome Possum", template: "- type: dropdown")
  end
  fab!(:form_template_4) do
    Fabricate(:form_template, name: "Biography", template: "- type: textarea")
  end
  fab!(:form_template_5) do
    Fabricate(
      :form_template,
      name: "Medication",
      template:
        %Q(
        - type: input
          attributes:
            label: "What is your name?"
            placeholder: "John Smith"
          validations:
            required: false
        - type: upload
          attributes:
            file_types: ".jpg, .png"
            allow_multiple: false
            label: "Upload your prescription"
            validations:
            required: true
        - type: upload
          attributes:
            file_types: ".jpg, .png, .pdf, .mp3, .mp4"
            allow_multiple: true
            label: "Any additional docs"
            validations:
            required: false"),
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

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:form_template_chooser) { PageObjects::Components::SelectKit.new(".form-template-chooser") }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.experimental_form_templates = true
    SiteSetting.authorized_extensions = "*"
    sign_in user
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
    category_page.visit(category_with_template_1)
    category_page.new_topic_button.click
    expect(composer).to have_no_composer_preview
    expect(composer).to have_no_composer_preview_toggle
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
    topic = Topic.where(user: user, title: topic_title)
    topic_id = Topic.where(user: user, title: topic_title).pluck(:id)
    post = Post.where(topic_id: topic_id).first

    expect(topic_page).to have_topic_title(topic_title)
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked p")).to have_content(
      "Bruce Wayne",
    )
  end

  it "creates a post with an upload field" do
    topic_title = "Bruce Wayne's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "upload-your-prescription-uploader",
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
    topic_title = "Bruce Wayne's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "upload-your-prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/animated.gif",
                make_visible: true
    expect(find("#dialog-holder .dialog-body p", visible: :all)).to have_content(
      I18n.t("js.pick_files_button.unsupported_file_picked", { types: ".jpg, .png" }),
    )
  end

  it "creates a post with multiple uploads" do
    topic_title = "Peter Parker's Medication"

    category_page.visit(category_with_upload_template)
    category_page.new_topic_button.click
    attach_file "upload-your-prescription-uploader",
                "#{Rails.root}/spec/fixtures/images/logo.png",
                make_visible: true
    attach_file "any-additional-docs-uploader",
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
    expect(find("#{topic_page.post_by_number_selector(1)} .cooked")).to have_css("video")
  end
end
