# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

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

  context "notification_level_visible" do
    let!(:tag1) { Fabricate(:tag) }
    let!(:tag2) { Fabricate(:tag) }
    let!(:tag3) { Fabricate(:tag) }
    let!(:tag4) { Fabricate(:tag) }
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    let!(:tag_user1) { TagUser.create(user: user1, tag: tag1, notification_level: TagUser.notification_levels[:watching]) }
    let!(:tag_user2) { TagUser.create(user: user1, tag: tag2, notification_level: TagUser.notification_levels[:tracking]) }
    let!(:tag_user3) { TagUser.create(user: user2, tag: tag3, notification_level: TagUser.notification_levels[:watching_first_post]) }
    let!(:tag_user4) { TagUser.create(user: user2, tag: tag4, notification_level: TagUser.notification_levels[:muted]) }

    it "scopes to notification levels visible due to absence of tag group" do
      expect(TagUser.notification_level_visible.length).to be(4)
    end

    it "scopes to notification levels visible by tag group permission" do
      group1 = Fabricate(:group)
      tag_group1 = Fabricate(:tag_group, tags: [tag1], permissions: { group1.name => 1 })

      group2 = Fabricate(:group)
      tag_group2 = Fabricate(:tag_group, tags: [tag2], permissions: { group2.name => 1 })

      Fabricate(:group_user, group: group1, user: user1)

      expect(TagUser.notification_level_visible.pluck(:id)).to match_array([
        tag_user1.id, tag_user3.id, tag_user4.id
      ])
    end

    it "scopes to notification levels visible because user is staff" do
      group2 = Fabricate(:group)
      tag_group2 = Fabricate(:tag_group, tags: [tag2], permissions: { group2.name => 1 })

      staff_group = Group.find(Group::AUTO_GROUPS[:staff])
      Fabricate(:group_user, group: staff_group, user: user1)

      expect(TagUser.notification_level_visible.length).to be(4)
    end

    it "scopes to notification levels visible by specified notification level" do
      expect(TagUser.notification_level_visible([TagUser.notification_levels[:watching]]).length).to be(1)
      expect(TagUser.notification_level_visible(
        [TagUser.notification_levels[:watching],
         TagUser.notification_levels[:tracking]]
      ).length).to be(2)
    end
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

    it "watches or tracks on change using a synonym" do
      user = Fabricate(:user)
      tag = Fabricate(:tag)
      synonym = Fabricate(:tag, target_tag: tag)
      post = create_post(tags: [tag.name])
      topic = post.topic

      TopicUser.change(user.id, topic.id, total_msecs_viewed: 1)

      TagUser.change(user.id, synonym.id, tracking)
      expect(TopicUser.get(topic, user).notification_level).to eq tracking

      TagUser.change(user.id, synonym.id, watching)
      expect(TopicUser.get(topic, user).notification_level).to eq watching

      TagUser.change(user.id, synonym.id, regular)
      expect(TopicUser.get(topic, user).notification_level).to eq tracking

      expect(TagUser.where(user_id: user.id, tag_id: synonym.id).first).to be_nil
      expect(TagUser.where(user_id: user.id, tag_id: tag.id).first).to be_present
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

    it "watches and unwatches tags correctly using tag synonym" do

      user = Fabricate(:user)
      tag = Fabricate(:tag)
      synonym = Fabricate(:tag, target_tag: tag)
      post = create_post(tags: [tag.name])
      topic = post.topic

      # we need topic user record to ensure watch picks up other wise it is implicit
      TopicUser.change(user.id, topic.id, total_msecs_viewed: 1)

      TagUser.batch_set(user, :tracking, [synonym.name])

      expect(TopicUser.get(topic, user).notification_level).to eq tracking

      TagUser.batch_set(user, :watching, [synonym.name])

      expect(TopicUser.get(topic, user).notification_level).to eq watching

      TagUser.batch_set(user, :watching, [])

      expect(TopicUser.get(topic, user).notification_level).to eq tracking
    end
  end

  context "integration" do
    fab!(:user) { Fabricate(:user) }
    fab!(:watched_tag) { Fabricate(:tag) }
    let(:muted_tag)   { Fabricate(:tag) }
    fab!(:tracked_tag) { Fabricate(:tag) }

    context "with some tag notification settings" do
      before do
        Jobs.run_immediately!
      end

      let :watched_post do
        TagUser.create!(user: user, tag: watched_tag, notification_level: TagUser.notification_levels[:watching])
        create_post(tags: [watched_tag.name])
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

        create_staff_only_tags(['foo'])

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ["foo"])
        expect(result).to eq(false)
        expect(topic.errors[:base].length).to eq(1)

        result = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(staff), ["foo"])
        expect(result).to eq(true)

        topic.errors.clear

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

  describe "#notification_levels_for" do
    let!(:tag1) { Fabricate(:tag) }
    let!(:tag2) { Fabricate(:tag) }
    let!(:tag3) { Fabricate(:tag) }
    let!(:tag4) { Fabricate(:tag) }

    context "for anon" do
      let(:user) { nil }
      before do
        SiteSetting.default_tags_watching = tag1.name
        SiteSetting.default_tags_tracking = tag2.name
        SiteSetting.default_tags_watching_first_post = tag3.name
        SiteSetting.default_tags_muted = tag4.name
      end
      it "every tag from the default_tags_* site settings get overridden to watching_first_post, except for muted" do
        levels = TagUser.notification_levels_for(user)
        expect(levels[tag1.name]).to eq(TagUser.notification_levels[:regular])
        expect(levels[tag2.name]).to eq(TagUser.notification_levels[:regular])
        expect(levels[tag3.name]).to eq(TagUser.notification_levels[:regular])
        expect(levels[tag4.name]).to eq(TagUser.notification_levels[:muted])
      end
    end

    context "for a user" do
      let(:user) { Fabricate(:user) }
      before do
        TagUser.create(user: user, tag: tag1, notification_level: TagUser.notification_levels[:watching])
        TagUser.create(user: user, tag: tag2, notification_level: TagUser.notification_levels[:tracking])
        TagUser.create(user: user, tag: tag3, notification_level: TagUser.notification_levels[:watching_first_post])
        TagUser.create(user: user, tag: tag4, notification_level: TagUser.notification_levels[:muted])
      end

      it "gets the tag_user notification levels for all tags the user is tracking and does not
      include tags the user is not tracking at all" do
        tag5 = Fabricate(:tag)
        levels = TagUser.notification_levels_for(user)
        expect(levels[tag1.name]).to eq(TagUser.notification_levels[:watching])
        expect(levels[tag2.name]).to eq(TagUser.notification_levels[:tracking])
        expect(levels[tag3.name]).to eq(TagUser.notification_levels[:watching_first_post])
        expect(levels[tag4.name]).to eq(TagUser.notification_levels[:muted])
        expect(levels.key?(tag5.name)).to eq(false)
      end

      it "does not show a tag is tracked if the user does not belong to the tag group with permissions" do
        group = Fabricate(:group)
        tag_group = Fabricate(:tag_group, tags: [tag2], permissions: { group.name => 1 })

        expect(TagUser.notification_levels_for(user).keys).to match_array([tag1.name, tag3.name, tag4.name])
      end
    end
  end
end
