# frozen_string_literal: true

describe "Composer Form Template" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tag1) { Fabricate(:tag, name: "persian") }
  fab!(:tag2) { Fabricate(:tag, name: "siamese") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Cat Breeds", tags: [tag1, tag2]) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      name: "Cat Template",
      template:
        "- type: tag-chooser\n  id: cat-breed\n  tag_group: \"Cat Breeds\"\n  attributes:\n    label: \"Cat Breed\"\n    none_label: \"Select a breed\"\n    multiple: false\n  validations:\n    required: true\n- type: input\n  id: notes\n  attributes:\n    label: \"Notes\"\n",
    )
  end
  fab!(:category) do
    Fabricate(
      :category,
      name: "Cats",
      slug: "cats",
      topic_count: 2,
      form_template_ids: [form_template.id],
    )
  end

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.enable_form_templates = true
    SiteSetting.show_preview_for_form_templates = true
    SiteSetting.tagging_enabled = true
    sign_in(user)
  end

  it "uses tag name instead of tag ID in form template preview" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator("#create-topic").filter(visible: true).click
    browser_root.locator(".category-chooser").filter(visible: true).click
    browser_root.locator(".category-row[data-value='#{category.id}']").filter(visible: true).click

    expect(
      browser_root.locator(".form-template-field__multi-select[name='cat-breed']").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_root
      .locator(".form-template-field__multi-select[name='cat-breed']")
      .filter(visible: true)
      .select_option(label: "PERSIAN")

    preview = browser_root.locator(".d-editor-preview").filter(visible: true)
    expect(preview).to PlaywrightMatchers.contain_text(
      browser_text_pattern("PERSIAN"),
      useInnerText: true,
    )
    expect(
      preview.tap do |parent|
        parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
      end,
    ).not_to PlaywrightMatchers.contain_text(browser_text_pattern(tag1.id.to_s), useInnerText: true)
  end
end

describe "Composer Form Template with uppercase tag names" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tag1) { Fabricate(:tag, name: "High") }
  fab!(:tag2) { Fabricate(:tag, name: "Low") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Priority", tags: [tag1, tag2]) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      name: "Issue Template",
      template:
        "- type: tag-chooser\n  id: priority\n  tag_group: \"Priority\"\n  attributes:\n    label: \"Priority\"\n    none_label: \"Select a priority\"\n    multiple: false\n  validations:\n    required: true\n",
    )
  end
  fab!(:category) do
    Fabricate(
      :category,
      name: "Issues",
      slug: "issues",
      topic_count: 2,
      form_template_ids: [form_template.id],
    )
  end

  before do
    SiteSetting.enable_form_templates = true
    SiteSetting.show_preview_for_form_templates = true
    SiteSetting.tagging_enabled = true
    SiteSetting.force_lowercase_tags = false
    sign_in(user)
  end

  it "selects a tag whose name contains uppercase characters" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator("#create-topic").filter(visible: true).click
    browser_root.locator(".category-chooser").filter(visible: true).click
    browser_root.locator(".category-row[data-value='#{category.id}']").filter(visible: true).click

    expect(
      browser_root.locator(".form-template-field__multi-select[name='priority']").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_root
      .locator(".form-template-field__multi-select[name='priority']")
      .filter(visible: true)
      .select_option(label: "HIGH")

    preview = browser_root.locator(".d-editor-preview").filter(visible: true)
    expect(preview).to PlaywrightMatchers.contain_text(
      browser_text_pattern("HIGH"),
      useInnerText: true,
    )
  end
end
