# frozen_string_literal: true

describe "Creating a boost" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:boost_page) { PageObjects::Pages::Boost.new }

  before do
    SiteSetting.discourse_boosts_enabled = true
    sign_in(current_user)
  end

  it "allows creating a boost on another user's post" do
    topic_page.visit_topic(topic)

    boost_page.click_post_menu_boost_button(post)
    boost_page.fill_in_boost(":heart:")
    boost_page.submit_boost

    expect(boost_page).to have_boost(post, ":heart:")
    expect(boost_page).to have_no_post_menu_boost_button(post)
    expect(boost_page).to have_no_boosts_list_boost_button(post)
  end
end
