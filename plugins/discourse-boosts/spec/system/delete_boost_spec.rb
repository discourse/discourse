# frozen_string_literal: true

describe "Deleting a boost", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:boost) { Fabricate(:boost, post: post, user: current_user) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:boost_page) { PageObjects::Pages::Boost.new }

  before do
    SiteSetting.discourse_boosts_enabled = true
    sign_in(current_user)
  end

  it "allows deleting own boost and shows the boost button again" do
    topic_page.visit_topic(topic)

    expect(boost_page).to have_boost(post)

    boost_page.click_boost_cooked(post)
    boost_page.click_delete_boost(post)

    expect(boost_page).to have_no_boosts(post)
    expect(boost_page).to have_post_menu_boost_button(post)
  end
end
