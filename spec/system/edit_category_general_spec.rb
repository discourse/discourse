# frozen_string_literal: true

describe "Edit Category General", type: :system do
  fab!(:admin)
  fab!(:category)
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  before { sign_in(admin) }

  context "when changing background color" do
    it "displays an error when the hex code is invalid" do
      category_page.visit_general(category)

      form.field("color").component.find("input.hex-input").fill_in(with: "ABZ")
      category_page.save_settings
      expect(form.field("color")).to have_errors(
        I18n.t("js.category.color_validations.non_hexdecimal"),
      )

      form.field("color").component.find("input.hex-input").fill_in(with: "")
      category_page.save_settings
      expect(form.field("color")).to have_errors(
        I18n.t("js.category.color_validations.cant_be_empty"),
      )

      form.field("color").component.find("input.hex-input").fill_in(with: "A")
      category_page.save_settings
      expect(form.field("color")).to have_errors(
        I18n.t("js.category.color_validations.incorrect_length"),
      )
    end

    it "saves successfully when the hex code is valid" do
      category_page.visit_general(category)

      form.field("color").component.find("input.hex-input").fill_in(with: "AB1")
      category_page.save_settings
      expect(form.field("color")).to have_no_errors
    end
  end

  context "when changing text color" do
    it "displays an error when the hex code is invalid" do
      category_page.visit_general(category)

      form.field("text_color").component.find("input.hex-input").fill_in(with: "ABZ")
      category_page.save_settings
      expect(form.field("text_color")).to have_errors(
        I18n.t("js.category.color_validations.non_hexdecimal"),
      )

      form.field("text_color").component.find("input.hex-input").fill_in(with: "")
      category_page.save_settings
      expect(form.field("text_color")).to have_errors(
        I18n.t("js.category.color_validations.cant_be_empty"),
      )

      form.field("text_color").component.find("input.hex-input").fill_in(with: "A")
      category_page.save_settings
      expect(form.field("text_color")).to have_errors(
        I18n.t("js.category.color_validations.incorrect_length"),
      )
    end

    it "saves successfully when the hex code is valid" do
      category_page.visit_general(category)

      form.field("text_color").component.find("input.hex-input").fill_in(with: "AB1")
      category_page.save_settings
      expect(form.field("text_color")).to have_no_errors
    end
  end
end
