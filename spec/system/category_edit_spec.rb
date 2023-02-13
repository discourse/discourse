# frozen_string_literal: true

describe "Edit Category", type: :system, js: true do
  fab!(:color_scheme) { Fabricate(:color_scheme) }
  fab!(:theme) { Fabricate(:theme) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:form_template) { Fabricate(:form_template) }
  fab!(:category) do
    Fabricate(:category, name: "Cool Category", slug: "cool-cat", topic_count: 3234)
  end
  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.experimental_form_templates = true
    sign_in(admin)
  end

  describe "when editing a category template" do
    it "should show the current category template or freeform as default" do
      category_page.visit_edit_template(category)
      expect(category_page).to have_template_value("Freeform")
      expect(category_page).to have_d_editor
    end

    it "should show a preview of the template selected" do
      category_page.visit_edit_template(category)
      category_page.toggle_form_template(form_template.name)
      expect(category_page).not_to have_d_editor
      expect(category_page).to have_template_preview(form_template.template)
    end

    it "should update the category form template upon save" do
      category_page.visit_edit_template(category)
      category_page.toggle_form_template(form_template.name)
      category_page.save_settings
      try_until_success { expect(Category.find_by_id(category.id).form_template).not_to eq(nil) }
    end
  end
end
