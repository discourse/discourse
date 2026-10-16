# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::BaseReport do
  fab!(:public_topic, :topic)
  fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }
  fab!(:private_message_topic)
  fab!(:restricted_topic) do
    Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
  end
  fab!(:topics) { [public_topic, unlisted_topic, private_message_topic, restricted_topic] }

  describe ".publicly_visible_topics" do
    it "only returns listed topics in public categories" do
      expect(described_class.publicly_visible_topics.where(id: topics)).to contain_exactly(
        public_topic,
      )
    end
  end

  describe ".publicly_visible_posts" do
    it "only returns visible, non-whisper posts in publicly visible topics" do
      public_post = Fabricate(:post, topic: public_topic)
      posts = [
        public_post,
        Fabricate(:post, topic: public_topic, hidden: true),
        Fabricate(:post, topic: public_topic, post_type: Post.types[:whisper]),
        *topics.drop(1).map { |topic| Fabricate(:post, topic:) },
      ]

      expect(described_class.publicly_visible_posts.where(id: posts)).to contain_exactly(
        public_post,
      )
    end
  end
end
