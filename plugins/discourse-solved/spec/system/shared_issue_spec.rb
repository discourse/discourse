# frozen_string_literal: true

describe "Solved | Shared issue button" do
  fab!(:author, :user)
  fab!(:member, :user)
  fab!(:support_category) do
    Fabricate(:category).tap do |c|
      c.upsert_custom_fields(DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => "true")
    end
  end
  fab!(:topic) do
    Fabricate(
      :post,
      user: author,
      topic: Fabricate(:topic, category: support_category, user: author),
    ).topic
  end
  fab!(:op) { topic.first_post }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:shared_issue_button) { PageObjects::Components::PostSharedIssueButton.new(op) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.enable_solved_shared_issues = true
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end

  it "lets a member toggle the shared issue on and off" do
    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button
    expect(shared_issue_button).to have_count(0)

    shared_issue_button.click
    expect(shared_issue_button).to have_count(1)
    expect(shared_issue_button).to have_active

    expect(TopicUser.get(topic, member).notification_level).to eq(
      TopicUser.notification_levels[:tracking],
    )

    shared_issue_button.click
    expect(shared_issue_button).to have_count(0)
    expect(shared_issue_button).to have_no_css(".has-shared-issue")
  end

  it "hides the button once the topic is solved" do
    answer_post = Fabricate(:post, topic:)
    solved_topic = Fabricate(:solved_topic, topic:)
    Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter: author)

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_no_shared_issue_button
  end

  it "re-shows the button after a solution is accepted then unaccepted" do
    answer_post = Fabricate(:post, topic:)

    sign_in(author)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button

    within("#post_#{answer_post.post_number}") do
      find(".post-action-menu__solved-unaccepted").click
    end
    expect(page).to have_css(".accepted-answers")
    expect(shared_issue_button).to have_no_shared_issue_button

    within("#post_#{answer_post.post_number}") { find(".post-action-menu__solved-accepted").click }
    expect(page).to have_no_css(".accepted-answers")
    expect(shared_issue_button).to have_shared_issue_button
  end

  it "hides the button when the upcoming change is disabled" do
    SiteSetting.enable_solved_shared_issues = false

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_no_shared_issue_button
  end

  it "hides the button when shared issues are disabled for the category" do
    support_category.upsert_custom_fields(
      DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD => "false",
    )

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_no_shared_issue_button
  end

  it "prompts anonymous visitors to log in" do
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button
    shared_issue_button.click

    expect(page).to have_current_path(%r{/login})
  end

  it "hides the button on topics outside a support category" do
    other_topic = Fabricate(:post, user: author).topic

    sign_in(member)
    topic_page.visit_topic(other_topic)

    expect(shared_issue_button).to have_no_shared_issue_button
  end

  it "shows the button as read-only when the topic is closed" do
    topic.update!(closed: true)

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button
    expect(shared_issue_button).to have_read_only
  end

  it "shows the button as read-only when the topic is archived" do
    topic.update!(archived: true)

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button
    expect(shared_issue_button).to have_read_only
  end

  it "shows the button as read-only for the topic author" do
    sign_in(author)
    topic_page.visit_topic(topic)

    expect(shared_issue_button).to have_shared_issue_button
    expect(shared_issue_button).to have_read_only
    expect(shared_issue_button).to have_count(0)
  end

  describe "with multiple solutions enabled" do
    before { SiteSetting.solved_allow_multiple_solutions = true }

    it "shows the button even after a solution is accepted" do
      answer_post = Fabricate(:post, topic:)
      solved_topic = Fabricate(:solved_topic, topic:)
      Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter: author)

      sign_in(member)
      topic_page.visit_topic(topic)

      expect(shared_issue_button).to have_shared_issue_button
    end

    it "lets a member create a shared issue on a solved topic" do
      answer_post = Fabricate(:post, topic:)
      solved_topic = Fabricate(:solved_topic, topic:)
      Fabricate(:topic_answer, solved_topic:, post: answer_post, accepter: author)

      sign_in(member)
      topic_page.visit_topic(topic)

      shared_issue_button.click
      expect(shared_issue_button).to have_active
      expect(shared_issue_button).to have_count(1)
    end
  end
end
