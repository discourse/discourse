# frozen_string_literal: true

require 'rails_helper'

describe ::Jobs::NotifyTagChange do

  fab!(:user) { Fabricate(:user) }
  fab!(:regular_user) { Fabricate(:trust_level_4) }
  fab!(:post) { Fabricate(:post, user: regular_user) }
  fab!(:tag) { Fabricate(:tag, name: 'test') }

  it "creates notification for watched tag" do
    TagUser.create!(
      user_id: user.id,
      tag_id: tag.id,
      notification_level: NotificationLevels.topic_levels[:watching]
    )
    TopicTag.create!(
      topic_id: post.topic.id,
      tag_id: tag.id
    )

    expect { described_class.new.execute(post_id: post.id, notified_user_ids: [regular_user.id]) }.to change { Notification.count }
    notification = Notification.last
    expect(notification.user_id).to eq(user.id)
    expect(notification.topic_id).to eq(post.topic_id)
    expect(notification.notification_type).to eq(Notification.types[:posted])
  end

  it 'doesnt create notification for user watching category' do
    CategoryUser.create!(
      user_id: user.id,
      category_id: post.topic.category_id,
      notification_level: TopicUser.notification_levels[:watching]
    )
    expect { described_class.new.execute(post_id: post.id, notified_user_ids: [regular_user.id]) }.not_to change { Notification.count }
  end
end
