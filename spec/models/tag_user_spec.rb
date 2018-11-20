# encoding: utf-8

require 'rails_helper'
require_dependency 'post_creator'

describe TagUser do
  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  def regular
    TagUser.notification_levels[:regular]
  end

  def tracking
    TagUser.notification_levels[:tracking]
  end

  def watching
    TagUser.notification_levels[:watching]
  end

  context "change" do
    it "watches or tracks on change" do
      user = Fabricate(:user)
      tag = Fabricate(:tag)
      post = create_post(tags: [tag.name])
      topic = post.topic

      TopicUser.change(user.id, topic.id, total_msecs_viewed: 1)

      TagUser.change(user.id, tag.id, tracking)
      expect(TopicUser.get(topic, user).notification_level).to eq tracking

      TagUser.change(user.id, tag.id, watching)
      expect(TopicUser.get(topic, user).notification_level).to eq watching

      TagUser.change(user.id, tag.id, regular)
      expect(TopicUser.get(topic, user).notification_level).to eq tracking
    end
  end

  context "batch_set" do
    it "watches and unwatches tags correctly" do

      user = Fabricate(:user)
      tag = Fabricate(:tag)
      post = create_post(tags: [tag.name])
      topic = post.topic

      # we need topic user record to ensure watch picks up other wise it is implicit
      TopicUser.change(user.id, topic.id, total_msecs_viewed: 1)

      TagUser.batch_set(user, :tracking, [tag.name])

      expect(TopicUser.get(topic, user).notification_level).to eq tracking

      TagUser.batch_set(user, :watching, [tag.name])

      expect(TopicUser.get(topic, user).notification_level).to eq watching

      TagUser.batch_set(user, :watching, [])

      expect(TopicUser.get(topic, user).notification_level).to eq tracking
    end
  end

  context "integration" do
    let(:user) { Fabricate(:user) }
    let(:watched_tag) { Fabricate(:tag) }
    let(:muted_tag)   { Fabricate(:tag) }
    let(:tracked_tag) { Fabricate(:tag) }

    context "with some tag notification settings" do
      before do
        SiteSetting.queue_jobs = false
      end

      let :watched_post do
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])
        create_post(tags: [watched_tag.name])
      end

      let :muted_post do
        TagUser.create!(user: user, tag: muted_tag,   notification_level: TagUser.notification_levels[:muted])
        create_post(tags: [muted_tag.name])
      end

      let :tracked_post do
        TagUser.create!(user: user, tag: tracked_tag, notification_level: TagUser.notification_levels[:tracking])
        create_post(tags: [tracked_tag.name])
      end

      it "sets notification levels correctly" do

        expect(Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count).to eq 1
        expect(Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count).to eq 0

        TopicUser.change(user.id, tracked_post.topic.id, total_msecs_viewed: 1)
        tu = TopicUser.get(tracked_post.topic, user)
        expect(tu.notification_level).to eq TopicUser.notification_levels[:tracking]
        expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_track_tag]
      end

      it "sets notification level to the highest one if there are multiple tags" do
        TagUser.create!(user: user, tag: tracked_tag, notification_level: TagUser.notification_levels[:tracking])
        TagUser.create!(user: user, tag: muted_tag,   notification_level: TagUser.notification_levels[:muted])
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])

        post = create_post(tags: [muted_tag.name, tracked_tag.name, watched_tag.name])

        expect(Notification.where(user_id: user.id, topic_id: post.topic_id).count).to eq 1

        TopicUser.change(user.id, post.topic.id, total_msecs_viewed: 1)
        tu = TopicUser.get(post.topic, user)
        expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]
        expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_watch_tag]
      end

      it "can start watching after tag has been added" do
        post = create_post

        # this is assuming post was already visited in the past, but now cause tag
        # was added we should start watching it
        TopicUser.change(user.id, post.topic.id, total_msecs_viewed: 1)
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])

        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [watched_tag.name])
        post.topic.save!

        tu = TopicUser.get(post.topic, user)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "can stop watching after tag has changed" do
        watched_tag2 = Fabricate(:tag)
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])
        TagUser.create!(user: user, tag: watched_tag2, notification_level: TagUser.notification_levels[:watching])

        post = create_post(tags: [watched_tag.name, watched_tag2.name])

        TopicUser.change(user.id, post.topic_id, total_msecs_viewed: 1)
        expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:watching]

        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [watched_tag.name])
        post.topic.save!
        expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:watching]

        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), [])
        post.topic.save!
        expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:tracking]

      end

      it "correctly handles staff tags" do

        staff = Fabricate(:admin)
        topic = create_post.topic

        create_staff_tags(['foo'])

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["foo"])
        expect(result).to eq(false)
        expect(topic.errors[:base].length).to eq(1)

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(staff), ["foo"])
        expect(result).to eq(true)

        topic.errors[:base].clear

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [])
        expect(result).to eq(false)
        expect(topic.errors[:base].length).to eq(1)

        topic.reload

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["foo", "bar"])
        expect(result).to eq(true)

        topic.reload
        expect(topic.tags.length).to eq(2)

      end

      it "is destroyed when a user is deleted" do
        TagUser.create!(user: user, tag: tracked_tag, notification_level: TagUser.notification_levels[:tracking])
        user.destroy!
        expect(TagUser.where(user_id: user.id).count).to eq(0)
      end
    end
  end
end
