# frozen_string_literal: true

RSpec.describe "Category Type Setup", type: :system do
  fab!(:current_user, :admin)

  before do
    SiteSetting.enable_simplified_category_creation = true
    sign_in(current_user)
  end

  it "automatically skips category type selection when only one type (discussion) is available" do
    visit("/new-category/setup")
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "discussion"))
    expect(page).to have_current_path("/new-category/general")
  end
end
