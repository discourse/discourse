# frozen_string_literal: true

require_relative "page_objects/member_onboarding"

RSpec.describe "Configure member onboarding" do
  fab!(:admin)

  let(:onboarding) { PageObjects::Pages::LovelaceMemberOnboarding.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "lets admins save compact checklist rows, preview safely, and keep their changes after reload" do
    onboarding.open
    onboarding.start_item
    onboarding.go_to_settings
    expect(dialog).to be_closed
    expect(page).to have_current_path("/admin/plugins/lovelace/settings")

    onboarding.open
    onboarding.add_item("Add profile picture")
    expect(onboarding).to have_saved_item("Add profile picture")
    expect(toasts).to have_success("Checklist saved.")
    expect(toasts).to have_no_message
    expect(onboarding).to have_preview_link("/my/preferences/profile")

    onboarding.preview_complete("Add profile picture")
    expect(onboarding).to have_progress("1 of 1 complete")
    onboarding.go_to_settings
    expect(dialog).to be_closed
    expect(page).to have_current_path("/admin/plugins/lovelace/settings")

    onboarding.open
    expect(onboarding).to have_progress("0 of 1 complete")
    onboarding.edit_item("Add profile picture")
    onboarding.go_to_settings
    expect(dialog).to be_closed
    expect(page).to have_current_path("/admin/plugins/lovelace/settings")

    onboarding.open
    onboarding.edit_item("Add profile picture")
    onboarding.editor.field("title").fill_in("Add an avatar")
    onboarding.go_to_settings
    expect(dialog).to be_open
    dialog.click_no
    onboarding.editor.submit
    expect(onboarding).to have_saved_item("Add an avatar")

    page.refresh
    expect(onboarding).to have_saved_item("Add an avatar")
    onboarding.add_item("Set notifications", destination: :notifications)
    expect(onboarding).to have_saved_item("Set notifications")
    onboarding.move_first_down
    expect(onboarding).to have_order(["Set notifications", "Add an avatar"])
    page.refresh
    expect(onboarding).to have_order(["Set notifications", "Add an avatar"])

    onboarding.drag_last_to_top
    expect(onboarding).to have_order(["Add an avatar", "Set notifications"])
    page.refresh
    expect(onboarding).to have_order(["Add an avatar", "Set notifications"])

    onboarding.remove_item("Set notifications")
    dialog.click_yes
    expect(onboarding).to have_no_item("Set notifications")
    page.refresh
    expect(onboarding).to have_no_item("Set notifications")
  end
end
