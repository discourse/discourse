# frozen_string_literal: true

describe "Composer Form Template Validations", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      name: "Bug Reports",
      template:
        "- type: input
  attributes:
    label: What is your full name?
    placeholder: John Doe
  validations:
    required: true
    type: email
    min: 10",
    )
  end

  fab!(:form_template_2) do
    Fabricate(
      :form_template,
      name: "Websites",
      template:
        "- type: input
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
      I18n.t("js.form_templates.errors.valueMissing.default"),
    )
  end

  it "shows an error when an input filled doesn't satisfy the type expected" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.create
    composer.fill_form_template_field("input", "Bruce Wayne")
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.typeMismatch.email"),
    )
  end

  it "shows an error when an input doesn't satisfy the min length expected" do
    category_page.visit(category_with_template)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.create
    composer.fill_form_template_field("input", "b@b.com")
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.tooShort", minLength: 10),
    )
  end

  it "shows an error when an input doesn't satisfy the requested pattern" do
    category_page.visit(category_with_template_2)
    category_page.new_topic_button.click
    composer.fill_title(topic_title)
    composer.fill_form_template_field("input", "www.example.com")
    composer.create
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.patternMismatch"),
    )
  end
end
