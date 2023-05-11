# frozen_string_literal: true

describe "Edit Category", type: :system, js: true do
  fab!(:color_scheme) { Fabricate(:color_scheme) }
  fab!(:theme) { Fabricate(:theme) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:form_template) { Fabricate(:form_template) }
  fab!(:form_template_2) { Fabricate(:form_template) }
  fab!(:category) do
    Fabricate(:category, name: "Cool Category", slug: "cool-cat", topic_count: 3234)
  end
  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.experimental_form_templates = true
    sign_in(admin)
  end

  describe "when editing a category with no form templates set" do
    before { category.update(form_template_ids: []) }

    it "should have form templates disabled and topic template enabled" do
      category_page.visit_edit_template(category)
      expect(category_page).not_to have_form_template_enabled
      expect(category_page).to have_d_editor
    end

    it "should allow you to select and save a form template" do
      category_page.visit_edit_template(category)
      category_page.toggle_form_templates
      expect(category_page).to have_no_d_editor
      category_page.select_form_template(form_template.name)
      expect(category_page).to have_selected_template(form_template.name)
      category_page.save_settings
      try_until_success do
        expect(Category.find_by_id(category.id).form_template_ids).to eq([form_template.id])
      end
    end

    it "should allow you to select and save multiple form templates" do
      category_page.visit_edit_template(category)
      category_page.toggle_form_templates
      category_page.select_form_template(form_template.name)
      category_page.select_form_template(form_template_2.name)
      category_page.save_settings
      try_until_success do
        expect(Category.find_by_id(category.id).form_template_ids).to eq(
          [form_template.id, form_template_2.id],
        )
      end
    end
  end

  describe "when editing a category with form templates set" do
    before { category.update(form_template_ids: [form_template.id, form_template_2.id]) }

    it "should have form templates enabled and showing the selected templates" do
      category_page.visit_edit_template(category)
      expect(category_page).to have_form_template_enabled
      expect(category_page).to have_no_d_editor
      selected_templates = "#{form_template.name},#{form_template_2.name}"
      expect(category_page).to have_selected_template(selected_templates)
    end
  end
end
