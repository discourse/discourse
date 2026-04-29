# frozen_string_literal: true

describe "Solved | Me too button" do
  fab!(:author, :user)
  fab!(:member, :user)
  fab!(:topic) { Fabricate(:post, user: author).topic }
  fab!(:op) { topic.first_post }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:me_too_button) { PageObjects::Components::PostMeTooButton.new(op) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.enable_solved_me_too = true
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
end
