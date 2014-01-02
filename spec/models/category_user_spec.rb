# encoding: utf-8

require 'spec_helper'
require_dependency 'post_creator'

describe CategoryUser do
  context 'integration' do
    before do
      ActiveRecord::Base.observers.enable :all
    end

    it 'should operate correctly' do
      watched_category = Fabricate(:category)
      muted_category = Fabricate(:category)
      user = Fabricate(:user)

      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: muted_category, notification_level: CategoryUser.notification_levels[:muted])

      watched_post = create_post(category: watched_category)
      muted_post = create_post(category: muted_category)

      Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count.should == 1

      tu = TopicUser.get(muted_post.topic, user)
      tu.notification_level.should == TopicUser.notification_levels[:muted]
      tu.notifications_reason_id.should == TopicUser.notification_reasons[:auto_mute_category]
    end

  end
end
