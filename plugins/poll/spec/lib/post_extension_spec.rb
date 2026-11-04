# frozen_string_literal: true

RSpec.describe DiscoursePoll::PostExtension do
  fab!(:post)

  before { allow(post).to receive(:publish_message!) }

  it "publishes only after the outermost transaction commits" do
    Post.transaction do
      Post.transaction(requires_new: true) { post.publish_poll_message! }
      expect(post).not_to have_received(:publish_message!)
    end

    expect(post).to have_received(:publish_message!).with(
      "/polls/#{post.topic_id}",
      post_id: post.id,
    )
  end

  it "does not publish when the transaction rolls back" do
    Post.transaction do
      post.publish_poll_message!
      raise ActiveRecord::Rollback
    end

    expect(post).not_to have_received(:publish_message!)
  end
end
