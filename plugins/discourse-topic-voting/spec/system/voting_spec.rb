# frozen_string_literal: true

RSpec.describe "Topic voting" do
  fab!(:user)
  fab!(:admin) { Fabricate(:admin, trust_level: TrustLevel[4]) }
  fab!(:category1, :category)
  fab!(:category2, :category)
  fab!(:voting_category) { Fabricate(:category, name: "voting category") }
  fab!(:topic1) { Fabricate(:topic, category: category1) }
  fab!(:topic2) { Fabricate(:topic, category: category1) }
  fab!(:topic3) { Fabricate(:topic, category: category2) }
  fab!(:voting_topic1) { Fabricate(:topic, category: voting_category) }
  fab!(:voting_topic2) { Fabricate(:topic, category: voting_category) }
  fab!(:voting_topic3) { Fabricate(:topic, category: voting_category) }
  fab!(:voting_topic4) { Fabricate(:topic, category: voting_category) }
  fab!(:post1) { Fabricate(:post, topic: topic1) }
  fab!(:post2) { Fabricate(:post, topic: topic2) }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:user_page) { PageObjects::Pages::User.new }
  let(:admin_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    SiteSetting.topic_voting_enabled = true
    sign_in(admin)
  end

  it "enables voting in category topics and votes" do
    category_page.visit(category1)
    expect(category_page).to have_no_css(category_page.votes)

    # enable voting in category
    category_page
      .visit_settings(category1)
      .toggle_setting("enable-topic-voting", "Allow users to vote on topics in this category")
      .save_settings

    expect(Category.can_vote?(category1.id)).to eq(true)

    # make a vote
    category_page.visit(category1)
    expect(category_page).to have_css(category_page.votes)
    category_page.select_topic(topic1)

    expect(topic_page.vote_count).to have_text("0")
    topic_page.vote
    expect(topic_page.vote_popup).to have_text(
      I18n.t("js.topic_voting.see_votes", count: 9, max: 10),
    )
    expect(topic_page.vote_count).to have_text("1")

    # visit user activity page
    topic_page.click_my_votes
    expect(user_page.active_user_primary_navigation).to have_text("Activity")
    expect(user_page.active_user_secondary_navigation).to have_text("Votes")
    expect(page).to have_css(".topic-list-body tr[data-topic-id=\"#{topic1.id}\"]")
    find(".topic-list-body tr[data-topic-id=\"#{topic1.id}\"] a.raw-link").click

    # unvoting
    topic_page.remove_vote
    expect(topic_page.vote_count).to have_text("0")
  end

  context "when navigating between voting topics" do
    fab!(:voting_post1) { Fabricate(:post, topic: voting_topic1) }
    fab!(:voting_post2) { Fabricate(:post, topic: voting_topic2) }
    fab!(:voting_post3) { Fabricate(:post, topic: voting_topic3) }

    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "resets vote UI state after route transitions" do
      voting_topic3.update!(closed: true)
      Fabricate(:post, topic: voting_topic3, raw: "Check out #{voting_topic1.url}")
      Fabricate(:post, topic: voting_topic1, raw: "Check out #{voting_topic2.url}")

      visit("/t/#{voting_topic3.slug}/#{voting_topic3.id}")
      expect(page).to have_css("button.voting-wrapper__button[disabled]")

      find("a[href='#{voting_topic1.url}']").click
      expect(page).to have_no_css("button.voting-wrapper__button[disabled]")

      topic_page.vote
      expect(topic_page.vote_popup).to have_text(
        I18n.t("js.topic_voting.see_votes", count: 9, max: 10),
      )

      find("a[href='#{voting_topic2.url}']").click
      expect(page).to have_no_css("button.voting-wrapper__button[disabled]")

      topic_page.vote
      expect(topic_page.vote_popup).to have_text(
        I18n.t("js.topic_voting.see_votes", count: 8, max: 10),
      )
    end
  end

  context "when toggling watch from the vote menu" do
    fab!(:voting_post) { Fabricate(:post, topic: voting_topic1) }

    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "sets the topic to watching" do
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      topic_page.vote
      expect(topic_page).to have_watch_toggle_off

      topic_page.click_watch_toggle
      expect(topic_page).to have_watch_toggle_on
      expect(TopicUser.find_by(user: admin, topic: voting_topic1).notification_level).to eq(
        TopicUser.notification_levels[:watching],
      )
    end
  end

  context "when viewing a closed voting topic without having voted" do
    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "does not show the remove vote button" do
      voting_topic1.update!(closed: true)
      Fabricate(:post, topic: voting_topic1)

      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")
      expect(page).to have_css("button.voting-wrapper__button[disabled]")
      expect(topic_page).to have_no_remove_vote_button
    end
  end

  context "when no votes are left" do
    before do
      DiscourseTopicVoting::CategorySetting.create!(category: category1)
      SiteSetting.topic_voting_tl4_vote_limit = 1
    end

    it "alerts the user" do
      category_page.visit(category1).select_topic(topic1)
      topic_page.vote

      expect(topic_page.vote_popup).to have_text(
        I18n.t("js.topic_voting.see_votes", count: 0, max: 1),
      )
    end
  end

  context "when viewing as anonymous user" do
    fab!(:voting_post) { Fabricate(:post, topic: voting_topic1) }

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: voting_category)
      Capybara.reset_session!
    end

    it "redirects to login when clicking vote" do
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")
      find(".title-voting button.voting-wrapper__button").click
      expect(page).to have_current_path("/login")
    end
  end

  context "when scrolling down on a voting topic" do
    fab!(:voting_posts) { Fabricate.times(21, :post, topic: voting_topic1) }

    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "shows voting in the docked header" do
      sign_in(admin)
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      expect(page).to have_css(".title-voting")
      expect(page).to have_no_css(".header-title-voting")

      page.execute_script("document.querySelector('#post_4').scrollIntoView()")

      expect(page).to have_css(".header-title-voting .voting-wrapper")
    end
  end

  context "when viewing who voted" do
    fab!(:voting_post) { Fabricate(:post, topic: voting_topic1) }

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: voting_category)
      SiteSetting.topic_voting_show_who_voted = true
      DiscourseTopicVoting::Vote.create!(user: admin, topic: voting_topic1)
      voting_topic1.update_vote_count
    end

    it "shows voter avatars in the popup" do
      sign_in(admin)
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      find(".title-voting .voting-wrapper__count").click
      expect(page).to have_css(".voting-voters__list")
      expect(page).to have_css(".voting-voters__avatar", count: 1)
    end

    it "shows empty state when no votes" do
      DiscourseTopicVoting::Vote.where(topic: voting_topic1).destroy_all
      voting_topic1.update_vote_count

      sign_in(admin)
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      find(".title-voting .voting-wrapper__count").click
      expect(page).to have_css(".voting-voters__empty")
    end
  end

  context "when viewing navigation tooltips" do
    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "shows custom tooltips in voting categories" do
      category_page.visit(voting_category)

      hot_item = find("#navigation-bar .nav-item_hot")
      votes_item = find("#navigation-bar .nav-item_votes")

      expect(hot_item["title"]).to eq(I18n.t("js.topic_voting.hot_nav_help"))
      expect(votes_item["title"]).to eq(I18n.t("js.filters.votes.help"))
    end

    it "shows default Hot tooltip in non-voting categories" do
      category_page.visit(category1)

      hot_item = find("#navigation-bar .nav-item_hot")
      expect(hot_item["title"]).to eq(I18n.t("js.filters.hot.help"))
    end
  end

  context "when vote limits are disabled" do
    fab!(:voting_post) { Fabricate(:post, topic: voting_topic1) }
    fab!(:voting_post2) { Fabricate(:post, topic: voting_topic2) }

    before do
      DiscourseTopicVoting::CategorySetting.create!(category: voting_category)
      SiteSetting.topic_voting_enable_vote_limits = false
      SiteSetting.topic_voting_tl4_vote_limit = 1
    end

    it "allows voting past the TL limit and hides limit UI" do
      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      topic_page.vote
      expect(topic_page.vote_count).to have_text("1")
      expect(topic_page).to have_voted

      visit("/t/#{voting_topic2.slug}/#{voting_topic2.id}")

      topic_page.vote
      expect(topic_page.vote_count).to have_text("1")
    end

    it "allows removing a vote" do
      DiscourseTopicVoting::Vote.create!(user: admin, topic: voting_topic1)
      voting_topic1.update_vote_count

      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")
      expect(topic_page.vote_count).to have_text("1")

      topic_page.remove_vote
      expect(topic_page.vote_count).to have_text("0")
    end
  end
end
