# frozen_string_literal: true

RSpec.describe "Admin tag list site setting", type: :system do
  fab!(:admin)
  fab!(:tag_1, :tag)
  fab!(:tag_2, :tag)

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before { sign_in(admin) }

  it "saves and persists tag selections" do
    settings_page.visit("digest_suppress_tags")

    tag_chooser = settings_page.tag_list_setting("digest_suppress_tags")
    tag_chooser.expand
    tag_chooser.search(tag_1.name)
    tag_chooser.select_row_by_name(tag_1.name)
    tag_chooser.search(tag_2.name)
    tag_chooser.select_row_by_name(tag_2.name)

    expect(settings_page).to have_tags_in_setting("digest_suppress_tags", [tag_1, tag_2])

    settings_page.save_setting("digest_suppress_tags")

    page.refresh

    expect(settings_page).to have_tags_in_setting("digest_suppress_tags", [tag_1, tag_2])
  end
end
