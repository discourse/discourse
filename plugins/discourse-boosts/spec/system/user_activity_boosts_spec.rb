# frozen_string_literal: true

describe "User activity boosts page" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
  fab!(:boost) { Fabricate(:boost, post: post, user: current_user) }

  let(:user_activity_boosts_page) { PageObjects::Pages::UserActivityBoosts.new }

  before do
    SiteSetting.discourse_boosts_enabled = true
    SiteSetting.hide_new_user_profiles = false
  end

  it "displays boosts given by the user" do
    sign_in(current_user)
    user_activity_boosts_page.visit(current_user)

    expect(user_activity_boosts_page).to have_boost_count(1)
    expect(user_activity_boosts_page).to have_boost_for_post(post)
  end

  it "displays boosts received on the user's posts" do
    sign_in(post_author)
    user_activity_boosts_page.visit_received(post_author)

    expect(user_activity_boosts_page).to have_boost_count(1)
    expect(user_activity_boosts_page).to have_boost_for_post(post)
  end

  it "shows empty state when user has no boosts" do
    sign_in(current_user)
    other_user = Fabricate(:user, refresh_auto_groups: true)

    user_activity_boosts_page.visit(other_user)

    expect(user_activity_boosts_page).to have_empty_state
  end

  context "with pagination" do
    fab!(:boosters) { Fabricate.times(20, :user) }
    fab!(:boosts) { boosters.map { |u| Fabricate(:boost, post: post, user: u) } }

    it "loads more boosts when scrolling" do
      sign_in(post_author)
      user_activity_boosts_page.visit_received(post_author)

      expect(user_activity_boosts_page).to have_boost_count(20)

      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

      expect(user_activity_boosts_page).to have_boost_count(21)
    end
  end
end
