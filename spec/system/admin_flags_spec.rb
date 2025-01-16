# frozen_string_literal: true

describe "Admin Flags Page", type: :system do
  fab!(:admin)
  fab!(:post)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:admin_flags_page) { PageObjects::Pages::AdminFlags.new }
  let(:admin_flag_form_page) { PageObjects::Pages::AdminFlagForm.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:d_page_header) { PageObjects::Components::DPageHeader.new }

  before do
    sign_in(admin)
    SiteSetting.custom_flags_limit = 1
  end

  it "allows admin to disable, change order, create, update and delete flags" do
    # disable
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit
    expect(d_page_header).to be_visible

    admin_flags_page.toggle("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices("It's Inappropriate", "It's Illegal", "Something Else")

    Flag.system.where(name: "spam").update!(enabled: true)

    # change order
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit.move_down("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Illegal",
      "It's Spam",
      "Something Else",
    )

    admin_flags_page.visit.move_up("spam")
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    # create
    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )

    admin_flags_page.visit

    expect(admin_flags_page).to have_add_flag_button_enabled

    admin_flags_page.click_add_flag
    expect(d_page_header).to be_hidden

    admin_flag_form_page
      .fill_in_name("Vulgar")
      .fill_in_description("New flag description")
      .select_applies_to("Topic")
      .select_applies_to("Post")
      .click_save

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "Vulgar",
    )

    expect(admin_flags_page).to have_add_flag_button_disabled

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
      "Vulgar",
    )

    # update
    admin_flags_page.visit.click_edit_flag("custom_vulgar")
    expect(d_page_header).to be_hidden
    admin_flag_form_page.fill_in_name("Tasteless").click_save

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "Tasteless",
    )

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
      "Tasteless",
    )

    # delete
    admin_flags_page.visit.click_delete_flag("custom_tasteless").confirm_delete

    expect(admin_flags_page).to have_no_flag("custom_tasteless")

    expect(admin_flags_page).to have_add_flag_button_enabled

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
    )
  end

  it "has settings tab" do
    admin_flags_page.visit

    expect(admin_flags_page).to have_tabs(
      [I18n.t("admin_js.settings"), I18n.t("admin_js.admin.config_areas.flags.flags_tab")],
    )

    admin_flags_page.click_tab("settings")
    expect(page.all(".setting-label h3").map(&:text).map(&:downcase)).to eq(
      [
        "silence new user sensitivity",
        "num users to silence new user",
        "flag sockpuppets",
        "num flaggers to close topic",
        "auto respond to flag actions",
        "high trust flaggers auto hide posts",
        "max flags per day",
        "tl2 additional flags per day multiplier",
        "tl3 additional flags per day multiplier",
        "tl4 additional flags per day multiplier",
      ],
    )
  end

  it "allows to create custom flag with same name as system flag" do
    admin_flags_page.visit
    admin_flags_page.click_add_flag
    admin_flag_form_page
      .fill_in_name("Inappropriate")
      .fill_in_description("New flag description")
      .select_applies_to("Topic")
      .select_applies_to("Post")
      .click_save

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "Inappropriate",
    )

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "It's Spam",
      "It's Illegal",
      "Something Else",
      "Inappropriate",
    )

    admin_flags_page.visit.click_delete_flag("custom_inappropriate").confirm_delete
  end

  it "does not allow to move notify user flag" do
    admin_flags_page.visit
    expect(admin_flags_page).to have_no_action_for_flag("notify_user")
  end

  it "does not allow bottom flag to move down" do
    admin_flags_page.visit.open_flag_menu("notify_moderators")
    expect(admin_flags_page).to have_no_item_action("move-down")
  end

  it "does not allow to system flag to be edited" do
    admin_flags_page.visit
    expect(admin_flags_page).to have_disabled_edit_for_flag("off_topic")
  end

  it "does not allow to system flag to be deleted" do
    admin_flags_page.visit.open_flag_menu("notify_moderators")
    expect(admin_flags_page).to have_disabled_item_action("delete")
  end

  it "does not allow top flag to move up" do
    admin_flags_page.visit.open_flag_menu("off_topic")
    expect(admin_flags_page).to have_no_item_action("move-up")
  end
end
