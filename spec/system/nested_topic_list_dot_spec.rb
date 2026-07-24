# frozen_string_literal: true

RSpec.describe "Nested topic-list new-replies dot" do
  fab!(:op_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let!(:topic) do
    post = create_post(user: op_user, raw: "Original post for the nested topic test")
    post.topic
  end

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_default = true

    # OP has visited and read; another user posted afterwards.
    TopicUser.find_or_create_by(user: op_user, topic: topic).update!(
      last_visited_at: 5.minutes.ago,
      first_visited_at: 5.minutes.ago,
      last_read_post_number: 1,
    )
    create_post(user: other_user, topic_id: topic.id, raw: "A reply from someone else")
    topic.reload.update!(bumped_at: 1.minute.ago, last_post_user_id: other_user.id)

    sign_in(op_user)
  end

  it "shows the dot on the topic list and clears it after visiting the topic" do
    visit("/latest")
    expect(topic_list).to have_new_replies_dot(topic)

    topic_list.click_topic_title(topic)
    expect(page).to have_css(".nested-view")

    visit("/latest")
    expect(topic_list).to have_no_new_replies_dot(topic)
  end
end
