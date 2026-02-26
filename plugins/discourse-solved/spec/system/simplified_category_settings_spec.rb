# frozen_string_literal: true

describe "Solved - Simplified Category Settings", type: :system do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before do
    SiteSetting.enable_simplified_category_creation = true
    SiteSetting.solved_enabled = true
    sign_in(admin)
  end

  describe "enable_accepted_answers" do
    it "saves 'true' when enabling accepted answers" do
      category_page.visit_settings(category)
      form.field("custom_fields.enable_accepted_answers").toggle
      category_page.save_settings

      expect(category.reload.custom_fields["enable_accepted_answers"]).to eq("true")
    end

    it "saves 'false' when disabling accepted answers" do
      category.upsert_custom_fields("enable_accepted_answers" => "true")

      category_page.visit_settings(category)
      form.field("custom_fields.enable_accepted_answers").toggle
      category_page.save_settings

      expect(category.reload.custom_fields["enable_accepted_answers"]).to eq("false")
    end
  end
end
