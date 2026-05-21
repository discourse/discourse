# frozen_string_literal: true

RSpec.describe "Category incoming new topic notifications" do
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

  it "opens the stale New count after a new topic is spam-deleted" do
    sign_in(admin)

    category_page.visit(category)

    expect(topic_list).to have_topic(existing_topic)

    new_post = create_post(category: category, user: author)

    try_until_success(reason: "relies on MessageBus updates") do
      expect(topic_list_controls).to have_new(count: 1)
    end

    PostActionCreator.spam(moderator, new_post).reviewable.perform(moderator, :delete_and_agree)

    category_page.click_new

    expect(topic_list_controls).to have_new(count: 0)
  end
end
