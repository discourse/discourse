# frozen_string_literal: true

RSpec.describe "Post voting" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:user1) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user2) { Fabricate(:user, refresh_auto_groups: true) }

  let(:topic_page) { PageObjects::Pages::PostVotingTopic.new }

  it "lets a reporter open the illegal content form for a comment on a subfolder site" do
    set_subfolder "/forum"
    SiteSetting.post_voting_enabled = true
    SiteSetting.post_voting_comment_enabled = true
    SiteSetting.dsa_reporting_enabled = true
    topic = Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: user2)
    Fabricate(:post, topic: topic)
    answer = Fabricate(:post, topic: topic)
    comment = Fabricate(:post_voting_comment, post: answer, user: user1)
    flag_modal = PageObjects::Modals::Flag.new
    notice_page = PageObjects::Pages::DsaNotice.new
    sign_in(admin)

    topic_page.visit_topic(topic)
    topic_page.flag_comment(comment)
    expect(flag_modal).to be_open
    expect(flag_modal).to have_no_illegal_flag_choice
    flag_modal.choose_type(:spam)
    flag_modal.report_illegal_content

    expect(flag_modal).to be_closed
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to eq("")
  end

  it "does not display button to add a comment and does not show comments when `post_voting_comment_enabled` site setting is false" do
    SiteSetting.post_voting_comment_enabled = false
    SiteSetting.post_voting_enabled = true

    topic = Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: user2)
    post_1 = Fabricate(:post, topic: topic)
    post_2 = Fabricate(:post, topic: topic)

    sign_in(user1)

    topic_page.visit_topic(topic)

    expect(topic_page).to have_no_comment_menu
  end

  it "does not show a negative remaining voters label when downvotes outnumber upvotes" do
    SiteSetting.post_voting_enabled = true

    topic = Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: admin)
    post_1 = Fabricate(:post, topic: topic, user: admin)
    answer = Fabricate(:post, topic: topic, user: admin)

    user3 = Fabricate(:user, refresh_auto_groups: true)

    Fabricate(:post_voting_vote, votable: answer, user: user1)
    Fabricate(
      :post_voting_vote,
      votable: answer,
      user: user2,
      direction: PostVotingVote.directions[:down],
    )
    Fabricate(
      :post_voting_vote,
      votable: answer,
      user: user3,
      direction: PostVotingVote.directions[:down],
    )

    sign_in(admin)

    topic_page.visit_topic(topic)
    topic_page.click_vote_count(answer)

    expect(topic_page).to have_no_remaining_voters_label
  end

  it "disallows voting on archived or closed topics" do
    SiteSetting.post_voting_enabled = true
    topic = Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: user2, archived: true)
    Fabricate(:post, topic: topic, post_number: 2)
    post = Fabricate(:post, topic: topic, post_number: 3)
    Fabricate(:post_voting_comment, post: post, user: user1)

    sign_in(user1)

    topic_page.visit_topic(topic)

    expect(page).to have_css(PageObjects::Pages::PostVotingTopic::POST_VOTE_BUTTON, count: 4)
    expect(page).to have_css(
      "#{PageObjects::Pages::PostVotingTopic::POST_VOTE_BUTTON}:disabled",
      count: 4,
    )
    expect(page).to have_css("#{PageObjects::Pages::PostVotingTopic::COMMENT_VOTE_BUTTON}:disabled")
    expect(page).to have_no_css(PageObjects::Pages::PostVotingTopic::COMMENT_ACTIONS, visible: :all)
  end
end
