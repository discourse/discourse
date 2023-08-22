# frozen_string_literal: true

describe "Viewing top topics on categories page", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:category_list) { PageObjects::Components::CategoryList.new }
  let(:topic_view) { PageObjects::Components::TopicView.new }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  it "displays and updates new counter" do
    skip(<<~TEXT)
    Flaky at the following step:

    expect(category_list).to have_no_new_posts_badge
       expected `#<PageObjects::Components::CategoryList:0x00007fe27a3d2340>.has_no_new_posts_badge?` to be truthy, got false
    TEXT

    sign_in(user)

    visit("/categories")

    category_list.click_new_posts_badge(count: 1)
    category_list.click_topic(topic)

    expect(topic_view).to have_read_post(post)

    category_list.click_logo
    category_list.click_category_navigation

    expect(category_list).to have_category(category)
    expect(category_list).to have_no_new_posts_badge
  end
end
