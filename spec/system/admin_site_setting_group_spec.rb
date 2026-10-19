# frozen_string_literal: true

describe "Admin site setting group" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  it "saves the picked group and names it back" do
    settings_page.visit("site_contact_group_name")

    chooser = settings_page.group_setting("site_contact_group_name")
    chooser.expand
    chooser.select_row_by_value(group.id)

    settings_page.save_setting("site_contact_group_name")
    page.refresh

    expect(SiteSetting.site_contact_group_name).to eq(group.id.to_s)
    expect(settings_page.group_setting("site_contact_group_name")).to have_selected_name(group.name)
  end
end
