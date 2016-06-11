# encoding: utf-8

require 'rails_helper'
require_dependency 'post_creator'

describe TagUser do

  context "integration" do
    before do
      ActiveRecord::Base.observers.enable :all
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_to_create_tag = 0
      SiteSetting.min_trust_level_to_tag_topics = 0
    end

    let(:user) { Fabricate(:user) }

    let(:watched_tag) { Fabricate(:tag) }
    let(:muted_tag)   { Fabricate(:tag) }
    let(:tracked_tag) { Fabricate(:tag) }

    context "with some tag notification settings" do
      before do
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])
        TagUser.create!(user: user, tag: muted_tag,   notification_level: TagUser.notification_levels[:muted])
        TagUser.create!(user: user, tag: tracked_tag, notification_level: TagUser.notification_levels[:tracking])
      end

      it "sets notification levels correctly" do
        watched_post = create_post(tags: [watched_tag.name])
        muted_post   = create_post(tags: [muted_tag.name])
        tracked_post = create_post(tags: [tracked_tag.name])

        expect(Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count).to eq 1
        expect(Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count).to eq 0

        tu = TopicUser.get(tracked_post.topic, user)
        expect(tu.notification_level).to eq TopicUser.notification_levels[:tracking]
        expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_track_tag]
      end

      it "sets notification level to the highest one if there are multiple tags" do
        post = create_post(tags: [muted_tag.name, tracked_tag.name, watched_tag.name])
        expect(Notification.where(user_id: user.id, topic_id: post.topic_id).count).to eq 1
        tu = TopicUser.get(post.topic, user)
        expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]
        expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_watch_tag]
      end

      it "can start watching after tag has been added" do
        post = create_post
        expect(TopicUser.get(post.topic, user)).to be_blank
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [watched_tag.name])
        tu = TopicUser.get(post.topic, user)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "can start watching after tag has changed" do
        post = create_post(tags: [Fabricate(:tag).name])
        expect(TopicUser.get(post.topic, user)).to be_blank
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [watched_tag.name])
        tu = TopicUser.get(post.topic, user)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "can stop watching after tag has changed" do
        post = create_post(tags: [watched_tag.name])
        expect(TopicUser.get(post.topic, user)).to be_present
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [Fabricate(:tag).name])
        expect(TopicUser.get(post.topic, user)).to be_blank
      end

      it "can stop watching after tags have been removed" do
        post = create_post(tags: [muted_tag.name, tracked_tag.name, watched_tag.name])
        expect(TopicUser.get(post.topic, user)).to be_present
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [])
        expect(TopicUser.get(post.topic, user)).to be_blank
      end

      it "is destroyed when a user is deleted" do
        expect(TagUser.where(user_id: user.id).count).to eq(3)
        user.destroy!
        expect(TagUser.where(user_id: user.id).count).to eq(0)
      end
    end
  end
end
