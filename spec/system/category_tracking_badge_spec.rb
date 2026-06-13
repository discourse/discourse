# frozen_string_literal: true

RSpec.describe "Category tracking badge" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:existing_topic) { Fabricate(:read_topic, category: category, current_user: admin) }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_list_controls) { PageObjects::Components::TopicListControls.new }

  before do
    CategoryUser.create!(
      category: category,
      user: admin,
      notification_level: CategoryUser.notification_levels[:watching],
    )
  end

  it "clears the New count after a new topic is spam-deleted" do
    sign_in(admin)

    category_page.visit(category)
    expect(topic_list).to have_topic(existing_topic)
    new_post = create_post(category: category, user: author)

    try_until_success(reason: "relies on MessageBus updates") do
      expect(topic_list_controls).to have_new(count: 1)
    end

    category_page.click_new
    expect(topic_list).to have_topic(new_post.topic)

    PostActionCreator.spam(moderator, new_post).reviewable.perform(moderator, :delete_and_agree)

    try_until_success(reason: "relies on MessageBus updates") do
      expect(topic_list_controls).to have_new(count: 0)
    end
  end

  context "when a reply post in a watched topic is spam-deleted" do
    before do
      Jobs.run_immediately!
      TopicUser.change(
        admin.id,
        existing_topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )
    end

    it "clears the Unread count" do
      sign_in(admin)

      category_page.visit(category)
      expect(topic_list).to have_topic(existing_topic)

      reply = create_post(category: category, user: author, topic: existing_topic)

      try_until_success(reason: "relies on MessageBus updates") do
        expect(topic_list_controls).to have_unread(count: 1)
      end

      PostActionCreator.spam(moderator, reply).reviewable.perform(moderator, :delete_and_agree)

      try_until_success(reason: "relies on MessageBus updates") do
        expect(topic_list_controls).to have_no_unread
      end
    end
  end
end
