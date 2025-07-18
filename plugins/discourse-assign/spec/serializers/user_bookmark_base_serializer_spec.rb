# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

describe UserBookmarkBaseSerializer do
  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    add_to_assign_allowed_group(user)
  end

  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new(user) }

  context "for Topic bookmarkable" do
    let!(:bookmark) { Fabricate(:bookmark, user: user, bookmarkable: post.topic) }
    it "includes assigned user in serializer" do
      Assigner.new(topic, user).assign(user)
      serializer = UserTopicBookmarkSerializer.new(bookmark, scope: guardian)
      bookmark = serializer.as_json[:user_topic_bookmark]

      expect(bookmark[:assigned_to_user][:id]).to eq(user.id)
      expect(bookmark[:assigned_to_group]).to be(nil)
    end

    it "includes assigned group in serializer" do
      Assigner.new(topic, user).assign(assign_allowed_group)
      serializer = UserTopicBookmarkSerializer.new(bookmark, scope: guardian)
      bookmark = serializer.as_json[:user_topic_bookmark]

      expect(bookmark[:assigned_to_group][:id]).to eq(assign_allowed_group.id)
      expect(bookmark[:assigned_to_user]).to be(nil)
    end
  end

  context "for Post bookmarkable" do
    let!(:bookmark) { Fabricate(:bookmark, user: user, bookmarkable: post) }
    it "includes assigned user in serializer" do
      Assigner.new(topic, user).assign(user)
      serializer = UserPostBookmarkSerializer.new(bookmark, scope: guardian)
      bookmark = serializer.as_json[:user_post_bookmark]

      expect(bookmark[:assigned_to_user][:id]).to eq(user.id)
      expect(bookmark[:assigned_to_group]).to be(nil)
    end

    it "includes assigned group in serializer" do
      Assigner.new(topic, user).assign(assign_allowed_group)
      serializer = UserPostBookmarkSerializer.new(bookmark, scope: guardian)
      bookmark = serializer.as_json[:user_post_bookmark]

      expect(bookmark[:assigned_to_group][:id]).to eq(assign_allowed_group.id)
      expect(bookmark[:assigned_to_user]).to be(nil)
    end
  end
end
