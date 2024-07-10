# frozen_string_literal: true

describe "TopicRequiredWords" do
  fab!(:user)
  fab!(:category) { Fabricate(:category, user: user) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::TOPIC_REQUIRED_WORDS,
      trigger: DiscourseAutomation::Triggers::TOPIC,
    )
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    topic.upsert_custom_fields(discourse_automation_ids: automation.id)
    automation.upsert_field!("words", "text_list", { value: %w[#foo #bar] })
  end

  describe "editing/creating a post" do
    before do
      automation.upsert_field!("restricted_topic", "text", { value: topic.id }, target: "trigger")
    end

    context "when topic has a topic_required_words automation associated" do
      context "when post has at least a required word" do
        it "validates the post" do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: "this is quite cool #foo")
          post = post_creator.create
          expect(post.valid?).to be(true)
        end
      end

      context "when post has no required word" do
        it "doesn’t validate the post" do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: "this is quite cool")
          post = post_creator.create
          expect(post.valid?).to be(false)
        end
      end
    end

    context "when topic has no topic_required_words automation associated" do
      context "when post has no required word" do
        it "validates the post" do
          no_automation_topic = create_topic(category: category)
          post_creator =
            PostCreator.new(user, topic_id: no_automation_topic.id, raw: "this is quite cool")
          post = post_creator.create
          expect(post.valid?).to be(true)
        end
      end
    end
  end

  describe "moving posts" do
    fab!(:admin)
    fab!(:first_post) { Fabricate(:post, topic: topic, raw: "this is quite cool #foo") }
    fab!(:post) { Fabricate(:post, topic: topic, raw: "this is quite cool #bar") }
    fab!(:destination_topic) { Fabricate(:post).topic }

    it "works" do
      expect do
        topic.move_posts(admin, [post.id], destination_topic_id: destination_topic.id)
      end.to_not raise_error

      expect(topic.posts.where(post_type: Post.types[:regular]).size).to eq(1)
      expect(destination_topic.posts.where(post_type: Post.types[:regular]).size).to eq(2)
    end
  end
end
