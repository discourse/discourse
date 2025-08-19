# frozen_string_literal: true

describe "Admin Flags Page", type: :system do
  fab!(:admin)
  fab!(:post)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:admin_flags_page) { PageObjects::Pages::AdminFlags.new }
  let(:admin_flag_form_page) { PageObjects::Pages::AdminFlagForm.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:d_page_header) { PageObjects::Components::DPageHeader.new }

  before { sign_in(admin) }

  it "allows admin to disable, change order, create, update and delete flags" do
    SiteSetting.custom_flags_limit = 4

    custom_flag =
      Fabricate(:flag, name: "flag1", description: "custom flag 1", applies_to: %w[Post Topic])

    custom_flag_2 =
      Fabricate(:flag, name: "flag2", description: "custom flag 2", applies_to: %w[Post Topic])

    custom_flag_3 =
      Fabricate(:flag, name: "flag3", description: "custom flag 3", applies_to: %w[Post Topic])

    admin_flags_page.visit
    expect(d_page_header).to be_visible

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Illegal",
      "Something Else",
      "flag1",
      "flag2",
      "flag3",
    )

    # disable flag
    admin_flags_page.toggle("spam")

    # change order
    admin_flags_page.move_down("illegal").move_up("custom_flag1")

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Something Else",
      "flag1",
      "Illegal",
      "flag2",
      "flag3",
    )

    # create flag
    admin_flags_page.click_add_flag
    expect(d_page_header).to be_hidden

    expect(admin_flag_form_page).to have_text(
      I18n.t("admin_js.admin.config_areas.flags.form.create_warning"),
    )

    admin_flag_form_page
      .fill_in_name("flag4")
      .fill_in_description("custom flag 4")
      .select_applies_to("Topic")
      .select_applies_to("Post")
      .click_save

    expect(admin_flags_page).to have_add_flag_button_disabled

    expect(admin_flags_page).to have_flags(
      "Send @%{username} a message",
      "Off-Topic",
      "Inappropriate",
      "Spam",
      "Something Else",
      "flag1",
      "Illegal",
      "flag2",
      "flag3",
      "flag4",
    )

    # update flag
    admin_flags_page.visit.click_edit_flag("custom_flag1")

    expect(d_page_header).to be_hidden

    expect(admin_flag_form_page).to have_text(
      I18n.t("admin_js.admin.config_areas.flags.form.edit_warning"),
    )

    admin_flag_form_page.fill_in_name("flag edited").click_save

    # delete flag
    admin_flags_page.visit.click_delete_flag("custom_flag3").confirm_delete

    expect(admin_flags_page).to have_no_flag("custom_flag3")

    topic_page.visit_topic(post.topic).open_flag_topic_modal

    expect(flag_modal).to have_choices(
      "It's Inappropriate",
      "Something Else",
      "flag edited",
      "It's Illegal",
      "flag2",
      "flag4",
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
        "flag post allowed groups",
        "allow all users to flag illegal content",
        "email address to report illegal content",
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
  end

  it "restricts actions on certain flags" do
    admin_flags_page.visit

    expect(admin_flags_page).to have_no_action_for_flag("notify_user")
    expect(admin_flags_page).to have_disabled_edit_for_flag("off_topic")

    admin_flags_page.toggle_flag_menu("notify_moderators")
    expect(admin_flags_page).to have_no_item_action("move-down")
    expect(admin_flags_page).to have_disabled_item_action("delete")
    admin_flags_page.toggle_flag_menu("notify_moderators")

    admin_flags_page.visit.toggle_flag_menu("off_topic")
    expect(admin_flags_page).to have_no_item_action("move-up")
  end
end
