# frozen_string_literal: true

RSpec.describe "Member onboarding checklist" do
  fab!(:admin)
  let(:checklist) { PageObjects::Pages::LovelaceChecklist.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "lets admins move seeded items between the checklist and bank and keeps their choices" do
    checklist.open_admin
    checklist.open_onboarding_tab
    expect(page).to have_current_path("/admin/plugins/lovelace/member-onboarding")
    expect(checklist).to have_onboarding_editor
    checklist.open_checklist_tab
    expect(page).to have_current_path("/admin/plugins/lovelace/checklist")
    expect(checklist).to have_selected_item("profile_picture")
    expect(checklist).to have_selected_item("profile")
    expect(checklist).to have_selected_item("guidelines")
    expect(checklist).to have_bank_item("notifications")

    checklist.move_to_bank("profile_picture")
    expect(checklist).to have_bank_item("profile_picture")
    checklist.open_admin
    expect(checklist).to have_bank_item("profile_picture")

    checklist.add_to_checklist("profile_picture")
    expect(checklist).to have_selected_item("profile_picture")
    checklist.add_to_checklist("notifications")
    expect(checklist).to have_selected_item("notifications")

    checklist.open_member
    expect(checklist).to have_member_link(
      "Add picture",
      "/u/#{admin.username_lower}/preferences/account",
    )
    expect(checklist).to have_member_link(
      "Complete profile",
      "/u/#{admin.username_lower}/preferences/profile",
    )
    expect(checklist).to have_member_link(
      "Set up notifications",
      "/u/#{admin.username_lower}/preferences/notifications",
    )
  end
end
