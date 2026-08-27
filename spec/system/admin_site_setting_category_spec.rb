# frozen_string_literal: true

describe "Admin site setting category" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)
  fab!(:category)

  before { sign_in(admin) }

  it "saves the picked category and names it back" do
    settings_page.visit("shared_drafts_category")

    chooser = settings_page.category_setting("shared_drafts_category")
    chooser.expand
    chooser.select_row_by_value(category.id)

    settings_page.save_setting("shared_drafts_category")
    page.refresh

    expect(SiteSetting.shared_drafts_category).to eq(category.id.to_s)
    expect(settings_page.category_setting("shared_drafts_category")).to have_selected_name(
      category.name,
    )
  end
end
