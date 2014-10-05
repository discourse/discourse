# encoding: utf-8

require 'spec_helper'
require_dependency 'post_creator'

describe CategoryUser do

  it 'allows batch set' do
    user = Fabricate(:user)
    category1 = Fabricate(:category)
    category2 = Fabricate(:category)

    watching = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:watching])

    CategoryUser.batch_set(user, :watching, [category1.id, category2.id])
    watching.pluck(:category_id).sort.should == [category1.id, category2.id]

    CategoryUser.batch_set(user, :watching, [])
    watching.count.should == 0

    CategoryUser.batch_set(user, :watching, [category2.id])
    watching.count.should == 1
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
      muted_post = create_post(category: muted_category)
      tracked_post = create_post(category: tracked_category)

      Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count.should == 1
      Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count.should == 0

      tu = TopicUser.get(tracked_post.topic, user)
      tu.notification_level.should == TopicUser.notification_levels[:tracking]
      tu.notifications_reason_id.should == TopicUser.notification_reasons[:auto_track_category]

    end

  end
end
