# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBookmarkSerializer do
  let(:bookmark) do
    Fabricate(:bookmark)
    Bookmark.all.includes(post: :user).includes(:topic).last
  end

  subject { described_class.new(bookmark) }

  context "when the topic is deleted" do
    before do
      bookmark.topic.trash!
      bookmark.reload
    end
    it "still returns the topic title because the relationship is unscoped" do
      expect(subject.title).not_to eq(nil)
    end
  end

  context "when the post is deleted" do
    before do
      bookmark.post.trash!
      bookmark.reload
    end
    it "still returns the post number because the relationship is unscoped" do
      expect(subject.linked_post_number).not_to eq(nil)
    end
    it "still returns the post username" do
      expect(subject.username).not_to eq(nil)
    end
  end
end
