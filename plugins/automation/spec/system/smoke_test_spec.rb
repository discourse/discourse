# frozen_string_literal: true

describe "DiscourseAutomation | smoke test", type: :system, js: true do
  fab!(:admin) { Fabricate(:admin) }

  before do
    Fabricate(:group, name: "test")
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  it "works" do
    visit("/admin/plugins/discourse-automation")

    find(".new-automation").click
    fill_in("automation-name", with: "aaaaa")
    select_kit = PageObjects::Components::SelectKit.new(".scriptables")
    select_kit.expand
    select_kit.select_row_by_value("user_group_membership_through_badge")
    find(".create-automation").click
    select_kit = PageObjects::Components::SelectKit.new(".triggerables")
    select_kit.expand
    select_kit.select_row_by_value("user_first_logged_in")
    fill_in("badge_name", with: "test")
    select_kit = PageObjects::Components::SelectKit.new(".group-chooser")
    select_kit.expand
    select_kit.select_row_by_name("test")
    find(".automation-enabled input").click
    find(".update-automation").click

    expect(page).to have_field("automation-name", with: "aaaaa")
  end
end
