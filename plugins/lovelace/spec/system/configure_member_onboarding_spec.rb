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

  it "shows matching compact rows with the controls for each area on wide and narrow screens" do
    onboarding.open
    description = "Add a picture to make your profile stand out."
    expect(onboarding).to have_checklist_row("Add a profile picture", description)
    expect(onboarding).to have_preview_row(
      "Add a profile picture",
      description,
      "Add picture",
      "/my/preferences/account",
    )
    expect(onboarding).to have_bank_row(
      "Set up your notifications",
      "Turn on push notifications to keep up to speed with the community.",
    )

    onboarding.preview_complete("Add a profile picture")
    expect(onboarding).to have_progress("1 of 3 complete")
    onboarding.preview_clear("Add a profile picture")
    expect(onboarding).to have_progress("0 of 3 complete")

    page.current_window.resize_to(1400, 1000)
    expect(onboarding).to have_grouped_configuration(stacked: false)
    page.current_window.resize_to(390, 844)
    expect(onboarding).to have_grouped_configuration(stacked: true)
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  it "returns unchanged suggestions to the bank without confirmation before and after reload" do
    onboarding.open
    onboarding.remove_item("Add a profile picture")
    expect(onboarding).to have_bank_item("Add a profile picture")
    expect(onboarding).to have_no_item("Add a profile picture")
    expect(dialog).to be_closed
    onboarding.add_suggestion("Add a profile picture")
    expect(onboarding).to have_saved_item("Add a profile picture")
    onboarding.add_suggestion("Set up your notifications")
    expect(onboarding).to have_saved_item("Set up your notifications")
    page.refresh
    onboarding.remove_item("Set up your notifications")
    expect(onboarding).to have_bank_item("Set up your notifications")
    expect(dialog).to be_closed
    onboarding.remove_item("Add a profile picture")
    expect(onboarding).to have_bank_item("Add a profile picture")
    expect(dialog).to be_closed
    page.refresh
    expect(onboarding).to have_no_item("Add a profile picture")
    expect(onboarding).to have_bank_item("Add a profile picture")
  end

  it "lets admins edit, return, and restore suggestions within the onboarding editor" do
    onboarding.open
    expect(onboarding).to have_order(
      ["Add a profile picture", "Complete your profile", "Read community guidelines"],
    )
    expect(onboarding).to have_bank_item("Set up your notifications")
    expect(onboarding).to have_progress("0 of 3 complete")
    expect(onboarding).to have_preview_link("/my/preferences/account")
    expect(onboarding).to have_preview_link("/my/preferences/profile")

    onboarding.edit_item("Add a profile picture")
    onboarding.editor.field("title").fill_in("Choose your avatar")
    onboarding.editor.submit
    expect(onboarding).to have_saved_item("Choose your avatar")
    page.refresh
    onboarding.remove_item("Choose your avatar")
    expect(dialog).to be_open
    dialog.click_no
    expect(onboarding).to have_saved_item("Choose your avatar")
    onboarding.remove_item("Choose your avatar")
    dialog.click_yes
    expect(onboarding).to have_no_item("Choose your avatar")
    expect(onboarding).to have_bank_item("Choose your avatar")
    page.refresh
    expect(onboarding).to have_bank_item("Choose your avatar")
    expect(onboarding).to have_order(["Complete your profile", "Read community guidelines"])

    onboarding.add_suggestion("Choose your avatar")
    expect(onboarding).to have_saved_item("Choose your avatar")
    expect(onboarding).to have_no_bank_item("Choose your avatar")
    onboarding.add_suggestion("Set up your notifications")
    expect(onboarding).to have_saved_item("Set up your notifications")
    expect(onboarding).to have_no_bank_item("Set up your notifications")
    expect(onboarding).to have_progress("0 of 4 complete")
    expect(onboarding).to have_preview_link("/my/preferences/notifications")
    page.refresh
    expect(onboarding).to have_order(
      [
        "Complete your profile",
        "Read community guidelines",
        "Choose your avatar",
        "Set up your notifications",
      ],
    )
    expect(onboarding).to have_empty_bank
    onboarding.go_to_settings
    expect(dialog).to be_closed
  end

  it "lets admins save compact checklist rows, preview safely, and keep their changes after reload" do
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 0 })
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
