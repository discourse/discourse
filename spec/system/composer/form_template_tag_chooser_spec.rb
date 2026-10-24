# frozen_string_literal: true

describe "Composer Form Template" do
  with_select_controls(false)

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
    visit("/")
    find("#create-topic").click
    find(".category-chooser").click
    find(".category-row[data-value='#{category.id}']").click

    expect(page).to have_css(".form-template-field__multi-select[name='cat-breed']")

    find(".form-template-field__multi-select[name='cat-breed']").select("PERSIAN")

    preview = find(".d-editor-preview")
    expect(preview).to have_content("PERSIAN")
    expect(preview).to have_no_content(tag1.id.to_s)
  end

  context "with the new select controls" do
    with_select_controls(true)

    let(:composer_tag_chooser) do
      PageObjects::Components::UiKit::DSelect.at(".tags-input .mini-tag-chooser")
    end

    def open_composer_in_category
      visit("/")
      find("#create-topic").click
      find(".category-chooser").click
      find(".category-row[data-value='#{category.id}']").click

      expect(page).to have_css(".form-template-field__multi-select[name='cat-breed']")
    end

    it "mirrors a form template tag into the composer tag chooser with the new select controls" do
      open_composer_in_category

      find(".form-template-field__multi-select[name='cat-breed']").select("PERSIAN")

      expect(composer_tag_chooser).to have_selected_names(tag1.name)

      preview = find(".d-editor-preview")
      expect(preview).to have_content("PERSIAN")
      expect(preview).to have_no_content(tag1.id.to_s)
    end

    it "mirrors a composer tag chooser pick into the form template field with the new select controls" do
      open_composer_in_category

      composer_tag_chooser.search(tag2.name)
      composer_tag_chooser.select_name(tag2.name)
      composer_tag_chooser.close

      expect(composer_tag_chooser).to have_selected_names(tag2.name)
      expect(page).to have_select("cat-breed", selected: "SIAMESE")
      expect(find(".d-editor-preview")).to have_content("SIAMESE")
    end
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
    visit("/")
    find("#create-topic").click
    find(".category-chooser").click
    find(".category-row[data-value='#{category.id}']").click

    expect(page).to have_css(".form-template-field__multi-select[name='priority']")

    find(".form-template-field__multi-select[name='priority']").select("HIGH")

    preview = find(".d-editor-preview")
    expect(preview).to have_content("HIGH")
  end
end
