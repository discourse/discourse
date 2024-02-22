# frozen_string_literal: true

RSpec.describe Jobs::CreateLinkedTopic do
  it "returns when the post cannot be found" do
    expect { Jobs::CreateLinkedTopic.new.execute(post_id: 1) }.not_to raise_error
  end

  context "with a post" do
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    let :watching do
      TopicUser.notification_levels[:watching]
    end

    let :tracking do
      TopicUser.notification_levels[:tracking]
    end

    let :muted do
      TopicUser.notification_levels[:muted]
    end

    before do
      SiteSetting.auto_close_topics_create_linked_topic = true
      Fabricate(:topic_user, notification_level: tracking, topic: topic, user: user_1)
      Fabricate(:topic_user, notification_level: muted, topic: topic, user: user_2)
    end

    it "creates a linked topic" do
      small_action_post =
        Fabricate(
          :post,
          topic: topic,
          post_type: Post.types[:small_action],
          action_code: "closed.enabled",
        )
      Jobs::CreateLinkedTopic.new.execute(post_id: post.id)

      raw_title = topic.title
      topic.reload
      new_topic = Topic.last
      linked_topic = new_topic.linked_topic
      expect(topic.title).to include(
        I18n.t("create_linked_topic.topic_title_with_sequence", topic_title: raw_title, count: 1),
      )
      expect(topic.posts.last.raw).to include(
        I18n.t(
          "create_linked_topic.small_action_post_raw",
          new_title: "[#{new_topic.title}](#{new_topic.url})",
        ),
      )
      expect(new_topic.title).to include(
        I18n.t("create_linked_topic.topic_title_with_sequence", topic_title: raw_title, count: 2),
      )
      expect(new_topic.first_post.raw).to include(topic.url)
      expect(new_topic.category.id).to eq(category.id)
      expect(new_topic.topic_users.count).to eq(3)
      expect(new_topic.topic_users.pluck(:notification_level)).to contain_exactly(
        muted,
        tracking,
        watching,
      )
      expect(linked_topic.topic_id).to eq(new_topic.id)
      expect(linked_topic.original_topic_id).to eq(topic.id)
      expect(linked_topic.sequence).to eq(2)
    end
  end
end
