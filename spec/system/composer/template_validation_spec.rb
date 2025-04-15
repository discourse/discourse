# frozen_string_literal: true

describe "Composer Form Template Validations", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      name: "Bug Reports",
      template:
        %Q(
        - type: input
          id: full-name
          attributes:
            label: "What is your full name?"
            placeholder: "John Doe"
          validations:
            required: true
            type: email
            minimum: 10

        - type: textarea
          id: full-text
          attributes:
            label: "Text"
            placeholder: "Full text"
          validations:
            required: false),
    )
  end

  fab!(:form_template_2) do
    Fabricate(
      :form_template,
      name: "Websites",
      template:
        "- type: input
  id: website-name
  attributes:
    label: What is your website name?
    placeholder: https://www.example.com
  validations:
    pattern: https?://.+",
    )
  end
  fab!(:category_with_template) do
    Fabricate(
      :category,
      name: "Reports",
      slug: "reports",
      topic_count: 2,
      form_template_ids: [form_template.id],
    )
  end
  fab!(:category_with_template_2) do
    Fabricate(
      :category,
      name: "Websites",
      slug: "websites",
      topic_count: 2,
      form_template_ids: [form_template_2.id],
    )
  end
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_title) { "A topic about Batman" }

  before do
    SiteSetting.experimental_form_templates = true
    sign_in user
  end

  context "when user is using preview" do
    context "when user is typing" do
      it "shows the cooked form if the user doesn't fill the required field first" do
        category_page.visit(category_with_template)
        category_page.new_topic_button.click

        composer.fill_title(topic_title)
        textarea = find("textarea")
        message = "This is a test message!"

        textarea.fill_in(with: message)

        expect(composer).to have_no_form_template_field_error(
          I18n.t("js.form_templates.errors.value_missing.default"),
        )

        preview = find(".d-editor-preview")
        expect(preview).to have_content(message)
      end
    end
  end

  it "shows an asterisk on the label of the required fields" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    expect(composer).to have_form_template_field_required_indicator("input")
  end

  it "shows an error when a required input is not filled in" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.create
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.value_missing.default"),
    )
  end

  it "shows an error when an input filled doesn't satisfy the type expected" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.create
    composer.fill_form_template_field("input", "Bruce Wayne")
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.type_mismatch.email"),
    )
  end

  it "shows an error when an input doesn't satisfy the min length expected" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.create
    composer.fill_form_template_field("input", "b@b.com")
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.too_short", count: 10),
    )
  end

  it "shows an error when an input doesn't satisfy the requested pattern" do
    category_page.visit(category_with_template_2)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "www.example.com")
    composer.create
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.pattern_mismatch"),
    )
  end
end
