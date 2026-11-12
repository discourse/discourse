# frozen_string_literal: true

RSpec.describe "Reading a DSA moderation notice" do
  fab!(:moderator)
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "lets the author read the moderator's selected rule in their removal notice" do
    rule = { ground: "Be respectful", explanation: "Personal attacks are not allowed." }
    enable_dsa_reporting(community_rules: [rule])
    SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
    reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
    Jobs::SendSystemMessage.clear
    reviewable.perform(
      moderator,
      :delete_and_agree,
      dsa_classification: {
        community_rule: DsaStatementOfRecord.community_rules.first,
        category: DsaStatementOfRecord::TERMS_VIOLATION_CATEGORY,
      },
    )
    Jobs::SendSystemMessage.new.execute(
      Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys,
    )
    notice = Post.last
    sign_in(post.user)

    topic_page.visit_topic(notice.topic)

    expect(topic_page).to have_post_content(
      post_number: 1,
      content:
        "More specifically, your post violated the following community guideline: #{rule[:ground]}. #{rule[:explanation]}",
    )
    expect(topic_page).to have_post_content(
      post_number: 1,
      content: "To appeal this decision, contact appeals@example.com",
    )
    page.refresh
    expect(topic_page).to have_post_content(post_number: 1, content: rule[:explanation])
  end
end
