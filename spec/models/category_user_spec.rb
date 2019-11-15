# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe CategoryUser do
  fab!(:user) { Fabricate(:user) }

  def tracking
    CategoryUser.notification_levels[:tracking]
  end

  def regular
    CategoryUser.notification_levels[:regular]
  end

  context '#batch_set' do
    fab!(:category) { Fabricate(:category) }

    def category_ids_at_level(level)
      CategoryUser.where(
        user_id: user.id,
        notification_level: CategoryUser.notification_levels[level]
      ).pluck(:category_id)
    end

    it "should add new records where required" do
      CategoryUser.batch_set(user, :watching, [category.id])

      expect(category_ids_at_level(:watching)).to eq([category.id])
    end

    it "should change existing records where required" do
      CategoryUser.create!(
        user_id: user.id,
        category_id: category.id,
        notification_level: CategoryUser.notification_levels[:muted]
      )

      CategoryUser.batch_set(user, :watching, [category.id])

      expect(category_ids_at_level(:watching)).to eq([category.id])
      expect(category_ids_at_level(:muted)).to eq([])
    end

    it "should delete extraneous records where required" do
      CategoryUser.create!(
        user_id: user.id,
        category_id: category.id,
        notification_level: CategoryUser.notification_levels[:watching]
      )

      CategoryUser.batch_set(user, :watching, [])

      expect(category_ids_at_level(:watching)).to eq([])
    end

    it "should return true when something changed" do
      expect(CategoryUser.batch_set(user, :watching, [category.id])).to eq(true)
    end

    it "should return false when nothing changed" do
      CategoryUser.batch_set(user, :watching, [category.id])

      expect(CategoryUser.batch_set(user, :watching, [category.id])).to eq(false)
    end
  end

  it 'should correctly auto_track' do
    tracking_user = Fabricate(:user)
    topic = Fabricate(:post).topic

    TopicUser.change(user.id, topic.id, total_msecs_viewed: 10)
    TopicUser.change(tracking_user.id, topic.id, total_msecs_viewed: 10)

    CategoryUser.create!(user: tracking_user, category: topic.category, notification_level: tracking)
    CategoryUser.auto_track(user_id: tracking_user.id)

    expect(TopicUser.get(topic, tracking_user).notification_level).to eq(tracking)
    expect(TopicUser.get(topic, user).notification_level).to eq(regular)
  end

  it 'allows updating notification level' do
    category = Fabricate(:category)

    CategoryUser.set_notification_level_for_category(user,
                                                     NotificationLevels.all[:watching_first_post],
                                                     category.id)

    expect(CategoryUser.where(user_id: user.id,
                              category_id: category.id,
                              notification_level: NotificationLevels.all[:watching_first_post]).exists?).to eq(true)

    CategoryUser.set_notification_level_for_category(user,
                                                     NotificationLevels.all[:regular],
                                                     category.id)

    expect(CategoryUser.where(user_id: user.id,
                              category_id: category.id,
                              notification_level: NotificationLevels.all[:regular]).exists?).to eq(true)
  end

  context 'integration' do
    before do
      Jobs.run_immediately!
      NotificationEmailer.enable
    end

    it 'should operate correctly' do
      watched_category = Fabricate(:category)
      muted_category = Fabricate(:category)
      tracked_category = Fabricate(:category)

      early_watched_post = create_post(category: watched_category)

      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: muted_category, notification_level: CategoryUser.notification_levels[:muted])
      CategoryUser.create!(user: user, category: tracked_category, notification_level: CategoryUser.notification_levels[:tracking])

      watched_post = create_post(category: watched_category)
      _muted_post = create_post(category: muted_category)
      tracked_post = create_post(category: tracked_category)

      create_post(topic_id: early_watched_post.topic_id)

      expect(Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count).to eq 1
      expect(Notification.where(user_id: user.id, topic_id: early_watched_post.topic_id).count).to eq 1
      expect(Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count).to eq 0

      # we must create a record so tracked flicks over
      TopicUser.change(user.id, tracked_post.topic_id, total_msecs_viewed: 10)
      tu = TopicUser.get(tracked_post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:tracking]
      expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_track_category]
    end

    it "topics that move to a tracked category should auto track" do
      first_post = create_post
      tracked_category = first_post.topic.category

      TopicUser.change(user.id, first_post.topic_id, total_msecs_viewed: 10)
      tu = TopicUser.get(first_post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:regular]

      CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[:tracking], tracked_category.id)

      tu = TopicUser.get(first_post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:tracking]
    end

    it "unwatches categories that have been changed" do
      watched_category = Fabricate(:category)
      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])

      post = create_post(category: watched_category)
      tu = TopicUser.get(post.topic, user)

      # we start watching cause a notification is sent to the watching user
      # this position sent is tracking in topic users
      expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]

      # Now, change the topic's category
      unwatched_category = Fabricate(:category)
      post.topic.change_category_to_id(unwatched_category.id)
      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:tracking]
    end

    it "does not delete TopicUser record when topic category is changed, and new category has same notification level" do
      # this is done so as to maintain topic notification state when topic category is changed and the new category has same notification level for the user
      # see: https://meta.discourse.org/t/changing-topic-from-one-watched-category-to-another-watched-category-makes-topic-new-again/36517/15

      watched_category_1 = Fabricate(:category)
      watched_category_2 = Fabricate(:category)
      category_3 = Fabricate(:category)

      post = create_post(category: watched_category_1)

      CategoryUser.create!(user: user, category: watched_category_1, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: watched_category_2, notification_level: CategoryUser.notification_levels[:watching])

      # we must have a topic user record otherwise it will be watched implicitly
      TopicUser.change(user.id, post.topic_id, total_msecs_viewed: 10)

      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:watching]

      post.topic.change_category_to_id(category_3.id)
      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:tracking]

      post.topic.change_category_to_id(watched_category_2.id)
      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:watching]

      post.topic.change_category_to_id(watched_category_1.id)
      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:watching]
    end

    it "deletes TopicUser record when topic category is changed, and new category has different notification level" do
      watched_category = Fabricate(:category)
      tracked_category = Fabricate(:category)
      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: tracked_category, notification_level: CategoryUser.notification_levels[:tracking])

      post = create_post(category: watched_category)
      tu = TopicUser.get(post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]

      # Now, change the topic's category
      post.topic.change_category_to_id(tracked_category.id)
      expect(TopicUser.get(post.topic, user).notification_level).to eq TopicUser.notification_levels[:tracking]
    end

    it "is destroyed when a user is deleted" do
      category = Fabricate(:category)

      CategoryUser.create!(user: user, category: category, notification_level: CategoryUser.notification_levels[:watching])

      expect(CategoryUser.where(user_id: user.id).count).to eq(1)

      user.destroy!

      expect(CategoryUser.where(user_id: user.id).count).to eq(0)
    end

  end
end
