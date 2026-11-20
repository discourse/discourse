# frozen_string_literal: true

describe "Staff post readers report" do
  fab!(:post)
  fab!(:moderator)
  fab!(:reader, :user)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(moderator) }

  it "shows recorded readers and topic visit data in the post admin menu when enabled" do
    SiteSetting.enable_post_readers_modal = true
    TopicUser.create!(topic: post.topic, user: reader, last_visited_at: 1.hour.ago)
    PostTiming.create!(topic: post.topic, user: reader, post_number: post.post_number, msecs: 700)

    topic_page.visit_topic(post.topic)
    topic_page.expand_post_actions(post)
    topic_page.expand_post_admin_actions(post)
    click_button I18n.t("js.post.readers_report.title")

    within(".post-readers-report") do
      expect(page).to have_link(reader.username)
      expect(page).to have_css(".relative-date[title]")
    end
  end

  it "omits the action by default" do
    topic_page.visit_topic(post.topic)
    topic_page.expand_post_actions(post)
    topic_page.expand_post_admin_actions(post)

    expect(topic_page).to have_post_admin_menu
    expect(page).to have_no_button(I18n.t("js.post.readers_report.title"))
  end
end
