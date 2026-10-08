# frozen_string_literal: true

RSpec.describe "Category card access" do
  fab!(:author, :admin)
  fab!(:allowed_group, :group)
  fab!(:allowed_user, :user)
  fab!(:denied_user, :user)
  fab!(:group_user) { Fabricate(:group_user, group: allowed_group, user: allowed_user) }
  fab!(:private_category) do
    Fabricate(
      :private_category,
      group: allowed_group,
      name: "Private category",
      slug: "private-category",
    )
  end
  fab!(:topic)
  fab!(:post_with_category_hashtag) do
    Fabricate(:post, raw: "See the #private-category category", topic: topic, user: author)
  end

  let(:category_card) { PageObjects::Components::CategoryCard.new }
  let(:hashtag_post) { PageObjects::Components::Post.new(post_with_category_hashtag.post_number) }
  let(:not_found_page) { PageObjects::Pages::NotFound.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { SiteSetting.enable_category_hashtag_cards = true }

  it "lets a logged-in user with permission open the category card" do
    sign_in(allowed_user)
    topic_page.visit_topic(topic, post_number: post_with_category_hashtag.post_number)

    hashtag_post.click_category_hashtag(private_category)

    expect(category_card).to be_showing_category(private_category)
  end

  it "keeps the category card closed for a logged-in user without permission" do
    sign_in(denied_user)
    topic_page.visit_topic(topic, post_number: post_with_category_hashtag.post_number)

    hashtag_post.click_category_hashtag(private_category)

    expect(not_found_page).to be_visible
    expect(category_card).to be_closed
  end

  it "keeps the category card closed for an anonymous user" do
    topic_page.visit_topic(topic, post_number: post_with_category_hashtag.post_number)

    hashtag_post.click_category_hashtag(private_category)

    expect(not_found_page).to be_visible
    expect(category_card).to be_closed
  end
end
