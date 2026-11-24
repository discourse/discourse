# frozen_string_literal: true

describe "Edit Category General" do
  fab!(:admin)
  fab!(:category)
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before { sign_in(admin) }

  it "allows limited edits from the category page for a category group moderator" do
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.category_group_moderators_can_edit_categories = true
    moderation = Fabricate(:category_moderation_group, category:)
    moderator = Fabricate(:user, refresh_auto_groups: true)
    moderation.group.add(moderator)
    sign_in(moderator)

    category_page.visit(category)
    category_page.click_edit_category
    expect(page).to have_no_css("a[href$='/edit/security']")
    expect(page).to have_no_css(".category-show-advanced-tabs-toggle")

    form.field("name").fill_in("Moderated announcements")
    category_page.save_settings

    expect(page).to have_content(I18n.t("js.saved"))
    expect(category.reload.name).to eq("Moderated announcements")

    category_page.visit_security(category)
    expect(form.field("name")).to have_value("Moderated announcements")
    expect(page).to have_no_css(".edit-category-tab-security")
  end

  context "when changing background color" do
    it "displays an error when the hex code is invalid" do
      category_page.visit_general(category)

      form.field("color").fill_in("ABZ")
      category_page.save_settings
      expect(form.field("color")).to have_errors(
        I18n.t("js.category.color_validations.non_hexdecimal"),
      )

      form.field("color").fill_in("A")
      category_page.save_settings
      expect(form.field("color")).to have_errors(
        I18n.t("js.category.color_validations.incorrect_length"),
      )
    end

    it "saves successfully when the hex code is valid" do
      category_page.visit_general(category)

      form.field("color").fill_in("AB1")
      category_page.save_settings
      expect(form.field("color")).to have_no_errors
    end
  end
end
