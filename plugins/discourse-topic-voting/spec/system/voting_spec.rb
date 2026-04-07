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
    expect(category_page).to have_css(category_page.topic_with_vote_count(0), count: 2)
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
    expect(page).to have_css(".topic-list-body tr[data-topic-id=\"#{topic1.id}\"]", text: "1 vote")
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
      expect(topic_page).to have_vote_button_label(I18n.t("js.topic_voting.voting_closed_title"))

      find("a[href='#{voting_topic1.url}']").click
      expect(topic_page).to have_vote_button_label(I18n.t("js.topic_voting.vote_title"))

      topic_page.vote
      expect(topic_page.vote_popup).to have_text(
        I18n.t("js.topic_voting.see_votes", count: 9, max: 10),
      )

      find("a[href='#{voting_topic2.url}']").click
      expect(topic_page).to have_vote_button_label(I18n.t("js.topic_voting.vote_title"))

      topic_page.vote
      expect(topic_page.vote_popup).to have_text(
        I18n.t("js.topic_voting.see_votes", count: 8, max: 10),
      )
    end
  end

  context "when viewing a closed voting topic without having voted" do
    before { DiscourseTopicVoting::CategorySetting.create!(category: voting_category) }

    it "does not show the remove vote button" do
      voting_topic1.update!(closed: true)
      Fabricate(:post, topic: voting_topic1)

      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")
      topic_page.vote
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
      expect(topic_page).to have_see_all_votes_link
      expect(topic_page).to have_no_votes_left_text
      expect(topic_page.vote_count).to have_text("1")

      visit("/t/#{voting_topic2.slug}/#{voting_topic2.id}")

      topic_page.vote
      expect(topic_page).to have_see_all_votes_link
      expect(topic_page).to have_no_votes_left_text
      expect(topic_page.vote_count).to have_text("1")
    end

    it "allows removing a vote" do
      DiscourseTopicVoting::Vote.create!(user: admin, topic: voting_topic1)
      voting_topic1.update_vote_count

      visit("/t/#{voting_topic1.slug}/#{voting_topic1.id}")

      topic_page.remove_vote
      expect(topic_page.vote_count).to have_text("0")
    end
  end
end
