# encoding: utf-8

require 'rails_helper'
require_dependency 'post_creator'

describe CategoryUser do

  it 'allows batch set' do
    user = Fabricate(:user)
    category1 = Fabricate(:category)
    category2 = Fabricate(:category)

    watching = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:watching])

    CategoryUser.batch_set(user, :watching, [category1.id, category2.id])
    expect(watching.pluck(:category_id).sort).to eq [category1.id, category2.id]

    CategoryUser.batch_set(user, :watching, [])
    expect(watching.count).to eq 0

    CategoryUser.batch_set(user, :watching, [category2.id])
    expect(watching.count).to eq 1
  end


  context 'integration' do
    before do
      ActiveRecord::Base.observers.enable :all
    end

    it 'should operate correctly' do
      watched_category = Fabricate(:category)
      muted_category = Fabricate(:category)
      tracked_category = Fabricate(:category)

      user = Fabricate(:user)

      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: muted_category, notification_level: CategoryUser.notification_levels[:muted])
      CategoryUser.create!(user: user, category: tracked_category, notification_level: CategoryUser.notification_levels[:tracking])

      watched_post = create_post(category: watched_category)
      _muted_post = create_post(category: muted_category)
      tracked_post = create_post(category: tracked_category)

      expect(Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count).to eq 1
      expect(Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count).to eq 0

      tu = TopicUser.get(tracked_post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:tracking]
      expect(tu.notifications_reason_id).to eq TopicUser.notification_reasons[:auto_track_category]
    end

    it "watches categories that have been changed" do
      user = Fabricate(:user)
      watched_category = Fabricate(:category)
      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])

      post = create_post
      expect(TopicUser.get(post.topic, user)).to be_blank

      # Now, change the topic's category
      post.topic.change_category_to_id(watched_category.id)
      tu = TopicUser.get(post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]
    end

    it "unwatches categories that have been changed" do
      user = Fabricate(:user)
      watched_category = Fabricate(:category)
      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])

      post = create_post(category: watched_category)
      tu = TopicUser.get(post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]

      # Now, change the topic's category
      unwatched_category = Fabricate(:category)
      post.topic.change_category_to_id(unwatched_category.id)
      expect(TopicUser.get(post.topic, user)).to be_blank
    end

    it "does not delete TopicUser record when topic category is changed, and new category has same notification level" do
      # this is done so as to maintain topic notification state when topic category is changed and the new category has same notification level for the user
      # see: https://meta.discourse.org/t/changing-topic-from-one-watched-category-to-another-watched-category-makes-topic-new-again/36517/15

      user = Fabricate(:user)
      watched_category_1 = Fabricate(:category)
      watched_category_2 = Fabricate(:category)
      CategoryUser.create!(user: user, category: watched_category_1, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: watched_category_2, notification_level: CategoryUser.notification_levels[:watching])

      post = create_post(category: watched_category_1)
      tu = TopicUser.get(post.topic, user)
      expect(tu.notification_level).to eq TopicUser.notification_levels[:watching]

      # Now, change the topic's category
      post.topic.change_category_to_id(watched_category_2.id)
      expect(TopicUser.get(post.topic, user)).to eq tu
    end

    it "deletes TopicUser record when topic category is changed, and new category has different notification level" do
      user = Fabricate(:user)
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
      user = Fabricate(:user)
      category = Fabricate(:category)

      CategoryUser.create!(user: user, category: category, notification_level: CategoryUser.notification_levels[:watching])

      expect(CategoryUser.where(user_id: user.id).count).to eq(1)

      user.destroy!

      expect(CategoryUser.where(user_id: user.id).count).to eq(0)
    end

  end
end
