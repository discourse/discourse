# frozen_string_literal: true

describe "Solved | Me too button" do
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
  let(:me_too_button) { PageObjects::Components::PostMeTooButton.new(op) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.enable_solved_me_too = true
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end

  it "lets a member toggle me too on and off" do
    sign_in(member)
    topic_page.visit_topic(topic)

    expect(me_too_button).to have_me_too_button
    expect(me_too_button).to have_count(1)

    me_too_button.click
    expect(me_too_button).to have_count(2)
    expect(me_too_button).to have_active

    expect(TopicUser.get(topic, member).notification_level).to eq(
      TopicUser.notification_levels[:tracking],
    )

    me_too_button.click
    expect(me_too_button).to have_count(1)
    expect(me_too_button).to have_no_css(".has-me-too")
  end

  it "hides the button once the topic is solved" do
    answer_post = Fabricate(:post, topic:)
    Fabricate(:solved_topic, topic:, answer_post:, accepter: author)

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(me_too_button).to have_no_me_too_button
  end

  it "hides the button when the upcoming change is disabled" do
    SiteSetting.enable_solved_me_too = false

    sign_in(member)
    topic_page.visit_topic(topic)

    expect(me_too_button).to have_no_me_too_button
  end

  it "prompts anonymous visitors to log in" do
    topic_page.visit_topic(topic)

    expect(me_too_button).to have_me_too_button
    me_too_button.click

    expect(page).to have_current_path(%r{/login})
  end

  it "hides the button on topics outside a support category" do
    other_topic = Fabricate(:post, user: author).topic

    sign_in(member)
    topic_page.visit_topic(other_topic)

    expect(me_too_button).to have_no_me_too_button
  end

  it "shows the button as read-only for the topic author" do
    sign_in(author)
    topic_page.visit_topic(topic)

    expect(me_too_button).to have_me_too_button
    expect(me_too_button).to have_read_only
    expect(me_too_button).to have_count(1)
  end
end
