# frozen_string_literal: true

describe "Edit Category General" do
  fab!(:admin)
  fab!(:category)
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before { sign_in(admin) }

  it "saves style changes for Uncategorized with the name disabled" do
    uncategorized = Category.find(SiteSetting.uncategorized_category_id)
    category_page.visit_general(uncategorized)
    expect(page).to have_field("name", with: uncategorized.name, disabled: true)

    find(".category-style-trigger").click
    find("[data-d-tab='square']").click
    fill_in("color", with: category.color)
    find(".category-style-trigger").click
    category_page.save_settings
    expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))

    page.refresh
    find(".category-style-trigger").click
    expect(page).to have_field("color", with: category.color)
    find(".form-kit__control-color-swatches-btn").click
    expect(page).to have_css(
      ".form-kit__control-color-swatch.is-used[data-color='#{category.color.upcase}']",
    )
  end

  context "when changing background color" do
    it "displays an error when the hex code is invalid" do
      category_page.visit_general(category)

      category_page.set_style_color("ABZ")
      category_page.save_settings
      expect(form.field("style_type")).to have_errors(
        I18n.t("js.category.color_validations.non_hexdecimal"),
      )

      category_page.set_style_color("A")
      category_page.save_settings
      expect(form.field("style_type")).to have_errors(
        I18n.t("js.category.color_validations.incorrect_length"),
      )
    end

    it "saves successfully when the hex code is valid" do
      category_page.visit_general(category)

      category_page.set_style_color("AB1")
      category_page.save_settings
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))
    end
  end
end
