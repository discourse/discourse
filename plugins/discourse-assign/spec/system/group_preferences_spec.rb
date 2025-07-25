# frozen_string_literal: true

RSpec.describe "Assign | Group Preferences", type: :system, js: true do
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.assign_enabled = true
    sign_in(admin)
  end

  it "allows to change who can assign a group" do
    visit "/g/#{group.name}/manage/interaction"
    select_kit = PageObjects::Components::SelectKit.new(".groups-form-assignable-level")

    expect(select_kit).to have_selected_value(0)

    select_kit.expand
    select_kit.select_row_by_value(99)

    expect(select_kit).to have_selected_value(99)

    page.find(".group-manage-save").click
    visit "/g/#{group.name}/manage/interaction"

    expect(select_kit).to have_selected_value(99)
  end
end
