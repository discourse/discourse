# frozen_string_literal: true

RSpec.describe MovedPost do
  fab!(:new_topic) { Fabricate(:topic) }
  fab!(:new_post) { Fabricate(:post, topic: new_topic) }

  fab!(:old_topic) { Fabricate(:topic) }
  fab!(:old_post) { Fabricate(:post, topic: old_topic) }

  fab!(:moved_post) do
    Fabricate(
      :moved_post,
      new_topic: new_topic,
      new_post: new_post,
      old_topic: old_topic,
      old_post: old_post,
    )
  end

  describe "Topic & Post associations" do
    it "deletes the MovePost record when new_topic is deleted" do
      new_topic.destroy
      expect { moved_post.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "deletes the MovePost record when old_topic is deleted" do
      old_topic.destroy
      expect { moved_post.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "deletes the MovePost record when new_post is deleted" do
      new_post.destroy
      expect { moved_post.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "deletes the MovePost record when old_post is deleted" do
      old_post.destroy
      expect { moved_post.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
