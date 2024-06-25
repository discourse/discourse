# frozen_string_literal: true

describe "Admin Flags Page", type: :system do
  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:admin_flags_page) { PageObjects::Pages::AdminFlags.new }

  before { sign_in(admin) }

  it "allows admin to disable flags" do
    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Spam", "It's Illegal", "Something Else"],
    )

    visit "/admin/config/flags"
    admin_flags_page.toggle("spam")

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

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["It's Inappropriate", "It's Illegal", "It's Spam", "Something Else"],
    )

    visit "/admin/config/flags"
    admin_flags_page.move_up("spam")

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

  it "does not allow top flag to move up" do
    visit "/admin/config/flags"
    admin_flags_page.open_flag_menu("off_topic")
    expect(page).not_to have_css(".dropdown-menu__item .move-up")
  end
end
