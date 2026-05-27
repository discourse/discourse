# frozen_string_literal: true

describe "Reactions | Post reaction user list" do
  fab!(:current_user, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:post) { Fabricate(:post, user: current_user) }

  let(:reactions_list) do
    PageObjects::Components::PostReactionsList.new("#post_#{post.post_number}")
  end
  let(:popup) { PageObjects::Components::PostReactionsPopup.new }

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

    reactions_list.click_counter

    expect(popup).to be_open
    find(".post-users-popup .post-users-popup__name[data-user-card=#{user_2.username}]").click

    expect(page).to have_css(".user-card.user-card-#{user_2.username}")
  end

  it "shows the user's name as primary when prioritize_username_in_ux is false" do
    SiteSetting.prioritize_username_in_ux = false

    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_counter

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

    reactions_list.click_counter

    expect(page).to have_css(
      ".post-users-popup__name[data-user-card=#{user_2.username}]",
      text: user_2.username,
    )
    expect(page).to have_no_css(".post-users-popup__username")
  end

  it "opens the users popup pre-filtered when clicking a specific reaction emoji" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_reaction("clap")

    expect(popup).to be_open
    expect(popup).to have_active_filter("clap")
    expect(popup).to have_no_active_filter("heart")
    expect(popup).to have_user(user_3.username)
    expect(popup).to have_no_user(user_2.username)
  end

  it "opens the users popup with no filter when clicking the counter number" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_counter_number

    expect(popup).to be_open
    expect(popup).to have_active_filter("all")
  end

  it "switches the active filter without reopening the menu when another emoji is clicked" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_reaction("heart")
    expect(popup).to have_active_filter("heart")

    reactions_list.click_reaction("clap")
    expect(popup).to have_active_filter("clap")
    expect(popup).to have_no_active_filter("heart")
  end

  it "switches to the all filter without reopening the menu when the counter number is clicked" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_reaction("heart")
    expect(popup).to have_active_filter("heart")

    reactions_list.click_counter_number
    expect(popup).to have_active_filter("all")
    expect(popup).to have_no_active_filter("heart")
  end

  it "filters the users popup by reaction" do
    sign_in(current_user)
    visit(post.url)
    expect(reactions_list).to have_reaction("heart")

    reactions_list.click_counter_number
    expect(popup).to be_open

    expect(popup).to have_user(user_2.username)
    expect(popup).to have_user(user_3.username)

    popup.click_filter("heart")
    expect(popup).to have_user(user_2.username)
    expect(popup).to have_no_user(user_3.username)

    popup.click_filter("clap")
    expect(popup).to have_user(user_3.username)
    expect(popup).to have_no_user(user_2.username)

    popup.click_filter("all")
    expect(popup).to have_user(user_2.username)
    expect(popup).to have_user(user_3.username)
  end
end
