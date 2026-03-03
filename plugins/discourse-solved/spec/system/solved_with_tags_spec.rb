# frozen_string_literal: true

describe "Solved with tags", type: :system do
  fab!(:user)
  fab!(:replier, :user)
  fab!(:tag)
  fab!(:unsolved_topic) { Fabricate(:topic_with_op, user:, tags: [tag]) }
  fab!(:reply) { Fabricate(:post, topic: unsolved_topic, user: replier) }
  fab!(:solved_topic) { Fabricate(:topic_with_op, tags: [tag]) }
  fab!(:answer_post) { Fabricate(:post, topic: solved_topic) }
  fab!(:solved_topic_record) do
    Fabricate(:solved_topic, topic: solved_topic, answer_post: answer_post)
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:tag_page) { PageObjects::Pages::Tag.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:solved_status_filter) { PageObjects::Components::SolvedStatusFilter.new }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = false
    SiteSetting.enable_solved_tags = tag.name
    SiteSetting.accept_solutions_topic_author = true
  end

  it "allows accepting an answer when topic has an enabled solved tag" do
    sign_in(user)
    topic_page.visit_topic(unsolved_topic, post_number: 2)

    post_solved_button = PageObjects::Components::PostSolvedButton.new(reply)

    expect(post_solved_button).to have_accept_button

    post_solved_button.accept_answer

    expect(post_solved_button).to have_accepted_button
  end

  it "does not show accept button on topics without enabled tags" do
    other_tag = Fabricate(:tag)
    other_topic = Fabricate(:topic_with_op, user:, tags: [other_tag])
    other_reply = Fabricate(:post, topic: other_topic)

    sign_in(user)
    topic_page.visit_topic(other_topic, post_number: 2)

    post_solved_button = PageObjects::Components::PostSolvedButton.new(other_reply)

    expect(post_solved_button).to have_no_accept_button
  end

  describe "confirmation modal when removing solved tag" do
    fab!(:admin)
    fab!(:other_tag, :tag)
    fab!(:topic_with_solved_tag) { Fabricate(:topic_with_op, user: admin, tags: [tag, other_tag]) }
    fab!(:answer) { Fabricate(:post, topic: topic_with_solved_tag) }
    fab!(:solved_record) do
      Fabricate(:solved_topic, topic: topic_with_solved_tag, answer_post: answer)
    end

    it "shows confirmation when removing the solved tag from a topic with an accepted answer" do
      sign_in(admin)
      topic_page.visit_topic(topic_with_solved_tag)

      topic_page.click_topic_edit_title

      tag_chooser = PageObjects::Components::SelectKit.new("#topic-title .mini-tag-chooser")
      tag_chooser.expand
      tag_chooser.unselect_by_name(tag.name)

      topic_page.click_topic_title_submit_edit

      expect(page).to have_css(".solved-removal-confirmation-modal")
    end
  end

  it "shows solved status filter on tag page and filters topics correctly" do
    SiteSetting.show_filter_by_solved_status = true

    sign_in(user)
    tag_page.visit_tag(tag)

    expect(solved_status_filter).to be_visible
    expect(topic_list).to have_topic(solved_topic)
    expect(topic_list).to have_topic(unsolved_topic)

    solved_status_filter.filter_solved

    expect(topic_list).to have_topic(solved_topic)
    expect(topic_list).to have_no_topic(unsolved_topic)

    solved_status_filter.filter_unsolved

    expect(topic_list).to have_no_topic(solved_topic)
    expect(topic_list).to have_topic(unsolved_topic)
  end
end
