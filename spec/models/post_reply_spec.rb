# frozen_string_literal: true

require 'rails_helper'

describe PostReply do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:other_post) { Fabricate(:post, topic: topic) }

  context "validation" do
    it "should ensure that the posts belong in the same topic" do
      expect(PostReply.new(post: post, reply: other_post)).to be_valid

      other_topic = Fabricate(:topic)
      other_post.update!(topic_id: other_topic.id)
      other_post.reload

      post_reply = PostReply.new(post: post, reply: other_post)
      expect(post_reply).to_not be_valid

      expect(post_reply.errors[:base]).to include(
        I18n.t("activerecord.errors.models.post_reply.base.different_topic")
      )
    end
  end
end
