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
      ["Something Else", "It's Inappropriate", "It's Spam", "It's Illegal"],
    )

    visit "/admin/config/flags"
    admin_flags_page.toggle("spam")

    topic_page.visit_topic(post.topic)
    topic_page.open_flag_topic_modal
    expect(all(".flag-action-type-details strong").map(&:text)).to eq(
      ["Something Else", "It's Inappropriate", "It's Illegal"],
    )
  end
end
