# frozen_string_literal: true

describe "Admin Flags Page", type: :system do
  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:admin_flags_page) { PageObjects::Pages::AdminFlags.new }
  let(:admin_flag_form_page) { PageObjects::Pages::AdminFlagForm.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(admin) }

  it "allows admin to disable flags" do
    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )

    visit "/admin/config/flags"
    admin_flags_page.toggle("spam")
    expect(page).not_to have_css(".admin-flag-item.spam.saving")

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Illegal", "Something Else"],
    )

    Flag.system.where(name: "spam").update!(enabled: true)
  end

  it "allows admin to change order of flags" do
    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )

    visit "/admin/config/flags"
    admin_flags_page.move_down("spam")
    expect(page).not_to have_css(".admin-flag-item.spam.saving")

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Illegal", "It's Spam", "Something Else"],
    )

    visit "/admin/config/flags"
    admin_flags_page.move_up("spam")
    expect(page).not_to have_css(".admin-flag-item.spam.saving")

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )
  end

  it "allows admin to create, edit and delete flags" do
    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )

    visit "/admin/config/flags"

    admin_flags_page.click_add_flag

    expect(admin_flag_form_page).to have_disabled_save_button

    admin_flag_form_page.fill_in_name("Vulgar")
    admin_flag_form_page.fill_in_description("New flag description")
    admin_flag_form_page.fill_in_applies_to("Topic")
    admin_flag_form_page.fill_in_applies_to("Post")
    admin_flag_form_page.click_save

    expect(all(".admin-flag-item__name").map(&:text)).to eq(
      [
        "Send @%{username} a message",
        "Off-Topic",
        "Inappropriate",
        "Spam",
        "Illegal",
        "Something Else",
        "Vulgar",
      ],
    )

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else", "Vulgar"],
    )

    visit "/admin/config/flags"

    admin_flags_page.click_edit_flag("vulgar")

    admin_flag_form_page.fill_in_name("Tasteless")
    admin_flag_form_page.click_save

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else", "Tasteless"],
    )

    visit "/admin/config/flags"
    admin_flags_page.click_delete_flag("tasteless")
    admin_flags_page.confirm_delete
    expect(page).not_to have_css(".admin-flag-item.tasteless.saving")

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )
  end

  it "does not allow to move notify user flag" do
    visit "/admin/config/flags"
    expect(page).not_to have_css(".notify_user .flag-menu-trigger")
  end

  it "does not allow bottom flag to move down" do
    visit "/admin/config/flags"
    admin_flags_page.open_flag_menu("notify_moderators")
    expect(page).not_to have_css(".dropdown-menu__item .move-down")
  end

  it "does not allow to system flag to be edited" do
    visit "/admin/config/flags"
    expect(page).to have_css(".off_topic .admin-flag-item__edit[disabled]")
  end

  it "does not allow to system flag to be deleted" do
    visit "/admin/config/flags"
    admin_flags_page.open_flag_menu("notify_moderators")
    expect(page).to have_css(".admin-flag-item__delete[disabled]")
  end

  it "does not allow top flag to move up" do
    visit "/admin/config/flags"
    admin_flags_page.open_flag_menu("off_topic")
    expect(page).not_to have_css(".dropdown-menu__item .move-up")
  end

  it "does not show the moderation flags link in the sidebar by default" do
    visit "/admin"
    sidebar.toggle_all_sections
    expect(sidebar).to have_no_section_link(
      I18n.t("admin_js.admin.community.sidebar_link.moderation_flags"),
    )
    SiteSetting.experimental_flags_admin_page_enabled_groups = Group::AUTO_GROUPS[:admins]
    visit "/admin"
    expect(sidebar).to have_section_link(
      I18n.t("admin_js.admin.community.sidebar_link.moderation_flags"),
    )
  end
end
