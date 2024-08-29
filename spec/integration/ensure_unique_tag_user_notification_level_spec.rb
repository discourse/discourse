# frozen_string_literal: true

require Rails.root.join("db/migrate/20240829083823_ensure_unique_tag_user_notification_level.rb")

RSpec.describe "EnsureUniqueTagUserNotificationLevel" do
  fab!(:tag1) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }

  fab!(:user)
  fab!(:user_with_duplicates1) do
    user = Fabricate(:user)
    Fabricate(:tag_user, user: user, tag: tag1, notification_level: 2)
    Fabricate(:tag_user, user: user, tag: tag1, notification_level: 3)
    user
  end
  fab!(:user_with_duplicates2) do
    user = Fabricate(:user)
    Fabricate(:tag_user, user: user, tag: tag1, notification_level: 4)
    Fabricate(:tag_user, user: user, tag: tag1, notification_level: 3)
    user
  end
  fab!(:user_with_two_unique_tag) do
    user = Fabricate(:user)
    Fabricate(:tag_user, user: user, tag: tag1, notification_level: 2)
    Fabricate(:tag_user, user: user, tag: tag2, notification_level: 3)
    user
  end

  it "keeps unique notification levels on tags" do
    EnsureUniqueTagUserNotificationLevel.new.up

    expect(user_with_two_unique_tag.tag_users.count).to eq(2)
  end

  it "removes duplicates and keeps the earlier created tag user" do
    EnsureUniqueTagUserNotificationLevel.new.up

    expect(user_with_duplicates1.tag_users.sole.notification_level).to eq(2)
    expect(user_with_duplicates2.tag_users.sole.notification_level).to eq(4)
  end
end
