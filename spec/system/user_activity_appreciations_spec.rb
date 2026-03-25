# frozen_string_literal: true

describe "User activity appreciations page" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }

  let(:appreciations_page) { PageObjects::Pages::UserActivityAppreciations.new }

  before { SiteSetting.hide_new_user_profiles = false }

  context "with likes" do
    before { PostActionCreator.like(current_user, post) }

    it "displays likes given by the user" do
      sign_in(current_user)
      appreciations_page.visit_given(current_user)

      expect(appreciations_page).to have_appreciation_count(1)
      expect(appreciations_page).to have_appreciation_for_post(post)
      expect(appreciations_page).to have_appreciation_type("like")
    end

    it "displays likes received on the user's posts" do
      sign_in(post_author)
      appreciations_page.visit_received(post_author)

      expect(appreciations_page).to have_appreciation_count(1)
      expect(appreciations_page).to have_appreciation_for_post(post)
      expect(appreciations_page).to have_appreciation_type("like")
    end
  end

  it "shows empty state when user has no appreciations" do
    sign_in(current_user)
    other_user = Fabricate(:user, refresh_auto_groups: true)

    appreciations_page.visit_given(other_user)

    expect(appreciations_page).to have_no_appreciations
  end
end
