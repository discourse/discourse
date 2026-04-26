# frozen_string_literal: true

describe "Reactions | Post reaction user list" do
  fab!(:current_user, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:post) { Fabricate(:post, user: current_user) }

  let(:reactions_list) do
    PageObjects::Components::PostReactionsList.new("#post_#{post.post_number}")
  end

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.enable_new_post_reactions_menu = true

    DiscourseReactions::ReactionManager.new(
      reaction_value: "heart",
      user: user_2,
      post: post,
    ).toggle!
    DiscourseReactions::ReactionManager.new(
      reaction_value: "clap",
      user: user_3,
      post: post,
    ).toggle!
  end

  it "shows more info about reactions when clicking" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    find(".discourse-reactions-counter").click

    expect(page).to have_css(".post-users-popup")
    find(".post-users-popup .post-users-popup__name[data-user-card=#{user_2.username}]").click

    expect(page).to have_css(".user-card.user-card-#{user_2.username}")
  end

  it "shows the user's name as primary when prioritize_username_in_ux is false" do
    SiteSetting.prioritize_username_in_ux = false

    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    find(".discourse-reactions-counter").click

    expect(page).to have_css(
      ".post-users-popup__name[data-user-card=#{user_2.username}]",
      text: user_2.name,
    )
    expect(page).to have_css(".post-users-popup__username", text: "@#{user_2.username}")
  end

  it "shows the user's username as primary when prioritize_username_in_ux is true" do
    SiteSetting.prioritize_username_in_ux = true

    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    find(".discourse-reactions-counter").click

    expect(page).to have_css(
      ".post-users-popup__name[data-user-card=#{user_2.username}]",
      text: user_2.username,
    )
    expect(page).to have_no_css(".post-users-popup__username")
  end

  it "filters the users popup by reaction" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    find(".discourse-reactions-counter").click
    expect(page).to have_css(".post-users-popup")

    within(".post-users-popup") do
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_2.username}]")
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_3.username}]")

      find("[data-reaction-filter=heart]").click
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_2.username}]")
      expect(page).to have_no_css(".post-users-popup__name[data-user-card=#{user_3.username}]")

      find("[data-reaction-filter=clap]").click
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_3.username}]")
      expect(page).to have_no_css(".post-users-popup__name[data-user-card=#{user_2.username}]")

      find("[data-reaction-filter=all]").click
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_2.username}]")
      expect(page).to have_css(".post-users-popup__name[data-user-card=#{user_3.username}]")
    end
  end
end
