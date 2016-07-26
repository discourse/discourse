require 'rails_helper'

describe PostReply do
  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }
  let(:other_post) { Fabricate(:post, topic: topic) }

  it { is_expected.to belong_to :post }
  it { is_expected.to belong_to :reply }

  context "validation" do
    it "should ensure that the posts belong in the same topic" do
      expect(PostReply.new(post: post, reply: other_post)).to be_valid

      other_topic = Fabricate(:topic)
      other_post.update_attributes!(topic_id: other_topic.id)
      other_post.reload

      post_reply = PostReply.new(post: post, reply: other_post)
      expect(post_reply).to_not be_valid

      expect(post_reply.errors[:base]).to include(
        I18n.t("activerecord.errors.models.post_reply.base.different_topic")
      )
    end
  end
end
