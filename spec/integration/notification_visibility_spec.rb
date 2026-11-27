# frozen_string_literal: true

RSpec.describe "Notification visibility", type: :request do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true, last_seen_at: Time.zone.now) }
  fab!(:admin)
  fab!(:group)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }

  def notify(type, topic: nil, data: {})
    Fabricate(
      :notification,
      user:,
      topic:,
      notification_type: Notification.types[type],
      data: data.to_json,
      read: false,
    )
  end

  def menu_notifications
    get "/notifications.json", params: { recent: true, limit: 30, silent: true }
    response.parsed_body["notifications"]
  end

  def page
    get "/notifications.json", params: { username: user.username }
    response.parsed_body
  end

  def published_state
    MessageBus
      .track_publish("/notification/#{user.id}") { user.publish_notifications_state }
      .first
      .data
  end

  def expect_no_visible_notification
    user.reload
    sign_in(user)

    expect(menu_notifications).to be_empty
    expect(page["notifications"]).to be_empty
    expect(published_state).to include(
      unread_notifications: 0,
      all_unread_notifications_count: 0,
      unread_high_priority_notifications: 0,
      new_personal_messages_notifications_count: 0,
      grouped_unread_notifications: {
      },
      available_notification_types: [],
    )
  end

  it "counts and lists a notification the user can see" do
    notification = notify(:edited, topic:)
    sign_in(user)

    expect(menu_notifications.map { |item| item["id"] }).to contain_exactly(notification.id)
    expect(page["notifications"].map { |item| item["id"] }).to contain_exactly(notification.id)
    expect(user.grouped_unread_notifications).to eq(Notification.types[:edited] => 1)
    expect(user.all_unread_notifications_count).to eq(1)
    expect(user.available_notification_types).to contain_exactly(Notification.types[:edited])
  end

  it "hides a notification when its category becomes restricted" do
    notify(:edited, topic:)
    category.set_permissions(group => :full)
    category.save!

    expect_no_visible_notification
  end

  it "hides a notification when the user leaves the group granting access to its category" do
    group.add(user)
    category.set_permissions(group => :full)
    category.save!
    notify(:edited, topic:)
    group.remove(user)

    expect_no_visible_notification
  end

  it "hides a notification when its topic moves to a restricted category" do
    notify(:edited, topic:)
    topic.change_category_to_id(Fabricate(:private_category, group:).id)

    expect_no_visible_notification
  end

  it "hides a notification when its topic becomes a shared draft" do
    SiteSetting.shared_drafts_category = category.id
    notify(:edited, topic:)
    SharedDraft.create!(topic:, category:)

    expect_no_visible_notification
  end

  it "hides a notification when its topic is trashed" do
    notify(:edited, topic:)
    topic.trash!(admin)

    expect_no_visible_notification
  end

  it "hides a notification when its topic is destroyed" do
    notify(:edited, topic:)
    topic.destroy!

    expect_no_visible_notification
  end

  context "when the notification points at a post" do
    fab!(:post) { Fabricate(:post, topic:) }

    before do
      Fabricate(
        :notification,
        user:,
        topic:,
        post_number: post.post_number,
        notification_type: Notification.types[:replied],
        read: false,
      )
    end

    it "hides the notification when the post is trashed" do
      post.trash!(admin)

      expect_no_visible_notification
    end

    it "keeps a collapsed notification while a later post it covers is visible" do
      later = Fabricate(:post, topic:)
      Notification.where(user:).update_all(data: { original_post_id: later.id }.to_json)
      post.trash!(admin)
      sign_in(user)

      expect(menu_notifications.size).to eq(1)
      expect(user.reload.all_unread_notifications_count).to eq(1)

      later.trash!(admin)

      expect_no_visible_notification
    end

    it "hides a notification covering only a hidden post even when a later post is visible" do
      Notification.where(user:).update_all(data: { original_post_id: post.id }.to_json)
      Fabricate(:post, topic:)
      post.trash!(admin)

      expect_no_visible_notification
    end

    it "hides a mention of a hidden post even when a later post is visible" do
      Notification.where(user:).update_all(notification_type: Notification.types[:mentioned])
      Fabricate(:post, topic:)
      post.trash!(admin)

      expect_no_visible_notification
    end

    it "hides the notification when the post is hidden" do
      post.update!(hidden: true)

      expect_no_visible_notification
    end

    it "hides the notification when the post becomes a whisper" do
      post.update!(post_type: Post.types[:whisper])

      expect_no_visible_notification
    end
  end

  it "hides a personal message notification when its topic is trashed" do
    notify(:private_message, topic: Fabricate(:private_message_topic, user: admin, recipient: user))
    Topic.last.trash!(admin)

    expect_no_visible_notification
  end

  it "hides a notification when the user loses the membership granting access to a group message" do
    group.add(user)
    message =
      Fabricate(
        :private_message_topic,
        user: admin,
        topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group:)],
      )
    notify(:private_message, topic: message)
    GroupUser.find_by(user:, group:).destroy!

    expect_no_visible_notification
  end

  it "hides a group inbox summary when the user leaves the group" do
    group.add(user)
    summary =
      notify(
        :group_message_summary,
        data: {
          group_id: group.id,
          group_name: group.name,
          inbox_count: 1,
        },
      )
    sign_in(user)

    expect(menu_notifications.map { |item| item["id"] }).to contain_exactly(summary.id)

    group.remove(user)

    expect_no_visible_notification
  end

  it "publishes current counts whenever the user fetches a notification list" do
    notify(:edited, topic:)
    category.set_permissions(group => :full)
    category.save!
    sign_in(user)

    [
      "/notifications.json?recent=true",
      "/notifications.json?username=#{user.username}",
      "/u/#{user.username}/user-menu-bookmarks.json",
      "/u/#{user.username}/user-menu-private-messages.json",
    ].each do |path|
      messages = MessageBus.track_publish("/notification/#{user.id}") { get path }

      expect(messages.map(&:data)).to contain_exactly(include(all_unread_notifications_count: 0))
    end
  end

  it "lists for staff only what both they and the owner can see, without publishing" do
    SiteSetting.suppress_secured_categories_from_admin = true
    group.add(user)
    notify(:edited, topic: Fabricate(:topic, category: Fabricate(:private_category, group:)))
    shared = notify(:edited, topic:)
    sign_in(admin)

    messages =
      MessageBus.track_publish("/notification/#{user.id}") do
        get "/notifications.json", params: { username: user.username }
      end

    expect(response.parsed_body["notifications"].map { |item| item["id"] }).to contain_exactly(
      shared.id,
    )
    expect(messages).to be_empty
  end

  it "hides a badge notification when badges are disabled" do
    notify(:granted_badge, data: { badge_id: Fabricate(:badge).id })
    SiteSetting.enable_badges = false

    expect_no_visible_notification
  end

  it "hides a badge notification when its badge is disabled" do
    badge = Fabricate(:badge)
    notify(:granted_badge, data: { badge_id: badge.id })
    badge.update!(enabled: false)

    expect_no_visible_notification
  end

  it "hides a reviewable mention when the user cannot see the review queue" do
    notify(:mentioned, data: { reviewable_id: Fabricate(:reviewable).id })

    expect_no_visible_notification
  end

  it "hides a like notification when the user disables like notifications" do
    notify(:liked, topic:)
    user.user_option.update!(
      like_notification_frequency: UserOption.like_notification_frequency_type[:never],
    )

    expect_no_visible_notification
  end
end
