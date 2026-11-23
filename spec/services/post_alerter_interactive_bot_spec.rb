# frozen_string_literal: true

RSpec.describe PostAlerter, "#after_save_post" do
  fab!(:bot) { Fabricate(:user, id: -100) }
  fab!(:human, :user)
  fab!(:root) { Fabricate(:post, user: bot) }

  before { bot.update!(interactive_bot: true, last_seen_at: nil) }

  def mention_post(**attributes)
    Fabricate(:post, user: human, topic: root.topic, raw: "Hello @#{bot.username}", **attributes)
  end

  def private_topic
    Fabricate(
      :topic,
      archetype: Archetype.private_message,
      category_id: nil,
      user: human,
      allowed_users: [human, bot],
    )
  end

  it "creates and publishes direct mentions on the native permission-scoped channel without a recent visit" do
    post = mention_post

    messages =
      MessageBus.track_publish("/notification/#{bot.id}") { PostAlerter.post_created(post) }

    notification = bot.notifications.sole
    expect(notification.notification_type).to eq(Notification.types[:mentioned])
    expect(notification.post_number).to eq(post.post_number)
    expect(messages).to be_present
    expect(messages.last.user_ids).to eq([bot.id])
    expect(messages.last.data.dig(:last_notification, :notification, :id)).to eq(notification.id)
  end

  it "records direct notifications without enqueuing email" do
    bot.user_option.update!(
      email_level: UserOption.email_level_types[:always],
      email_messages_level: UserOption.email_level_types[:always],
    )
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:watching])
    pm = Fabricate(:post, user: human, topic: topic)
    reply = Fabricate(:post, user: human, topic: root.topic, reply_to_post_number: root.post_number)
    mention = mention_post

    expect_not_enqueued_with(job: :user_email, args: { user_id: bot.id }) do
      PostAlerter.post_created(mention)
      PostAlerter.post_created(reply)
      PostAlerter.post_created(pm)
    end

    expect(bot.notifications.pluck(:notification_type)).to contain_exactly(
      Notification.types[:mentioned],
      Notification.types[:replied],
      Notification.types[:private_message],
    )
  end

  it "does not apply bot-only notification filtering to a human with the flag set" do
    human.update_column(:interactive_bot, true)
    post = Fabricate(:post, topic: root.topic)

    PostAlerter.new.create_notification(human, Notification.types[:posted], post)

    expect(human.notifications.sole.notification_type).to eq(Notification.types[:posted])
  end

  it "does not treat the system user as interactive even if the flag is set" do
    system = Discourse.system_user
    system.update_column(:interactive_bot, true)
    post = Fabricate(:post, user: human, raw: "Hello @#{system.username}")

    expect { PostAlerter.post_created(post) }.not_to change { system.notifications.count }
  end

  it "leaves non-opted-in bots excluded" do
    bot.update!(interactive_bot: false)

    expect { PostAlerter.post_created(mention_post) }.not_to change { bot.notifications.count }
  end

  it "notifies the author of the actual direct parent" do
    reply = Fabricate(:post, user: human, topic: root.topic, reply_to_post_number: root.post_number)

    PostAlerter.post_created(reply)

    expect(bot.notifications.sole.notification_type).to eq(Notification.types[:replied])
  end

  it "excludes ambient posts even when the bot watches the topic" do
    TopicUser.change(
      bot.id,
      root.topic.id,
      notification_level: TopicUser.notification_levels[:watching],
    )
    post = Fabricate(:post, user: human, topic: root.topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "excludes implicit topic-root replies in nested topics" do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_default = true
    post = Fabricate(:post, user: human, topic: root.topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "excludes replies to another participant even when the bot authored the topic" do
    parent = Fabricate(:post, user: human, topic: root.topic)
    reply = Fabricate(:post, topic: root.topic, reply_to_post_number: parent.post_number)
    TopicUser.change(
      bot.id,
      root.topic.id,
      notification_level: TopicUser.notification_levels[:watching],
    )

    expect { PostAlerter.post_created(reply) }.not_to change { bot.notifications.count }
  end

  it "excludes quotes and links" do
    post = Fabricate(:post, user: human, topic: root.topic)
    alerter = PostAlerter.new

    expect do
      alerter.create_notification(bot, Notification.types[:quoted], post)
      alerter.create_notification(bot, Notification.types[:linked], post)
    end.not_to change { bot.notifications.count }
  end

  it "requires an authentic direct mention rather than a mentioned notification candidate" do
    post = Fabricate(:post, user: human, topic: root.topic)

    expect do
      PostAlerter.new.create_notification(bot, Notification.types[:mentioned], post)
    end.not_to change { bot.notifications.count }
  end

  it "excludes group mentions and watching-first-post candidates" do
    group = Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
    group.add(bot)
    post = Fabricate(:post, user: human, raw: "Hello @#{group.name}")

    expect do
      PostAlerter.post_created(post)
      PostAlerter.new.notify_first_post_watchers(post, [bot.id])
    end.not_to change { bot.notifications.count }
  end

  it "excludes bot-authored and self-authored mentions" do
    other_bot = Fabricate(:user, id: -101)
    other_bot.update!(interactive_bot: true)
    other_post = mention_post(user: other_bot)
    self_post = mention_post(user: bot)

    expect do
      PostAlerter.post_created(other_post)
      PostAlerter.post_created(self_post)
    end.not_to change { bot.notifications.count }
  end

  it "excludes mentions introduced by a bot editor" do
    editor = Fabricate(:user, id: -101)
    post = mention_post(last_editor_id: editor.id)

    expect { PostAlerter.post_edited(post) }.not_to change { bot.notifications.count }
  end

  it "respects topic muting" do
    TopicUser.change(
      bot.id,
      root.topic.id,
      notification_level: TopicUser.notification_levels[:muted],
    )

    expect { PostAlerter.post_created(mention_post) }.not_to change { bot.notifications.count }
  end

  it "respects actor muting" do
    MutedUser.create!(user: bot, muted_user: human)

    expect { PostAlerter.post_created(mention_post) }.not_to change { bot.notifications.count }
  end

  it "respects secured category visibility" do
    category = Fabricate(:private_category, group: Fabricate(:group))
    post = mention_post(topic: Fabricate(:topic, category: category))

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "requires whisper entitlement even for an administrator bot" do
    bot.update!(admin: true)
    SiteSetting.whispers_allowed_groups = ""
    post = mention_post(post_type: Post.types[:whisper])

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "allows direct mentions in whispers when entitled" do
    bot.update!(admin: true)
    SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
    post = mention_post(post_type: Post.types[:whisper])

    PostAlerter.post_created(post)

    expect(bot.notifications.sole.notification_type).to eq(Notification.types[:mentioned])
  end

  it "notifies subscribed directly addressed PM recipients on initial and ordinary follow-up posts" do
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:watching])
    first = Fabricate(:post, user: human, topic: topic)
    follow_up = Fabricate(:post, user: human, topic: topic)

    PostAlerter.post_created(first)
    PostAlerter.post_created(follow_up)

    expect(bot.notifications.pluck(:notification_type).uniq).to eq(
      [Notification.types[:private_message]],
    )
    expect(
      bot.notifications.order(:post_number).map { |notice| notice.data_hash[:original_post_id] },
    ).to eq([first.id, follow_up.id])
    expect(bot.notifications.order(:post_number).pluck(:post_number)).to eq(
      [first.post_number, follow_up.post_number],
    )
  end

  it "respects PM subscription for ordinary follow-ups" do
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:tracking])
    post = Fabricate(:post, user: human, topic: topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "allows direct mentions and actual replies in a non-watched directly addressed PM" do
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:tracking])
    parent = Fabricate(:post, user: bot, topic: topic)
    reply = Fabricate(:post, user: human, topic: topic, reply_to_post_number: parent.post_number)
    mention = mention_post(topic: topic)

    PostAlerter.post_created(reply)
    PostAlerter.post_created(mention)

    expect(bot.notifications.pluck(:notification_type)).to contain_exactly(
      Notification.types[:private_message],
      Notification.types[:mentioned],
    )
  end

  it "requires explicit PM allowed_users membership, not group membership or admin visibility" do
    group = Fabricate(:group)
    group.add(bot)
    bot.update!(admin: true)
    topic =
      Fabricate(
        :topic,
        archetype: Archetype.private_message,
        category_id: nil,
        user: human,
        allowed_users: [human],
        allowed_groups: [group],
      )
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:watching])
    post = mention_post(topic: topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "excludes group PM summaries for tracking bots" do
    group = Fabricate(:group)
    group.add(bot)
    topic =
      Fabricate(
        :topic,
        archetype: Archetype.private_message,
        category_id: nil,
        user: human,
        allowed_groups: [group],
      )
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:tracking])
    post = Fabricate(:post, user: human, topic: topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "respects muting in subscribed directly addressed PMs" do
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:muted])
    post = mention_post(topic: topic)

    expect { PostAlerter.post_created(post) }.not_to change { bot.notifications.count }
  end

  it "notifies a watching PM recipient when a human adds a direct mention in an edit" do
    topic = private_topic
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:watching])
    post = Fabricate(:post, topic: topic, user: human)
    PostAlerter.post_created(post)
    post.update!(raw: "I forgot to mention @#{bot.username}")

    expect { Jobs::PostAlert.new.execute(post_id: post.id) }.not_to change {
      bot.notifications.count
    }
    Jobs::PostAlert.new.execute(post_id: post.id, added_mentions: [bot.username_lower])

    expect(bot.notifications.pluck(:notification_type)).to contain_exactly(
      Notification.types[:private_message],
      Notification.types[:mentioned],
    )
  end

  it "notifies a bot when a human adds a mention to a reply that already notified it" do
    reply = Fabricate(:post, topic: root.topic, user: human, reply_to_post_number: root.post_number)
    PostAlerter.post_created(reply)
    reply.update!(raw: "I forgot to mention @#{bot.username}")

    alerts =
      DiscourseEvent.track_events(:pre_notification_alert) do
        Jobs::PostAlert.new.execute(post_id: reply.id, added_mentions: [bot.username_lower])
      end

    expect(alerts.map { |alert| alert[:params].first }).to eq([bot])

    expect(bot.notifications.pluck(:notification_type)).to contain_exactly(
      Notification.types[:replied],
      Notification.types[:mentioned],
    )
  end

  it "attributes a newly created post's mention to the author even after a bot edit" do
    post = mention_post(last_editor_id: Discourse::SYSTEM_USER_ID)

    Jobs::PostAlert.new.execute(post_id: post.id, new_record: true)

    expect(bot.notifications.sole.data_hash[:original_username]).to eq(human.username)
  end

  it "attributes an edit's mention to the human editor who added it, not a later bot editor" do
    author = Fabricate(:bot)
    post = Fabricate(:post, topic: root.topic, user: author)

    expect_enqueued_with(
      job: :post_alert,
      args: {
        post_id: post.id,
        added_mentions: [bot.username_lower],
        editor_id: human.id,
      },
    ) do
      PostRevisor.new(post).revise!(
        human,
        { raw: "I forgot to mention @#{bot.username}" },
        skip_validations: true,
      )
    end
    post.update_column(:last_editor_id, Discourse::SYSTEM_USER_ID)
    Jobs::PostAlert.new.execute(
      post_id: post.id,
      added_mentions: [bot.username_lower],
      editor_id: human.id,
    )

    expect(bot.notifications.sole.data_hash[:original_username]).to eq(human.username)
  end

  it "keeps each direct reply at its own post number even with earlier unread posts" do
    TopicUser.change(
      bot.id,
      root.topic.id,
      notification_level: TopicUser.notification_levels[:watching],
    )
    Fabricate(:post, topic: root.topic, user: human)
    replies =
      Fabricate.times(
        2,
        :post,
        topic: root.topic,
        user: human,
        reply_to_post_number: root.post_number,
      )

    replies.each { |post| PostAlerter.post_created(post) }

    expect(bot.notifications.order(:post_number).pluck(:post_number)).to eq(
      replies.map(&:post_number),
    )
  end

  it "retains directly addressed PM recipients who also belong to an allowed group" do
    group = Fabricate(:group)
    group.add(bot)
    topic = private_topic
    topic.allowed_groups << group
    TopicUser.change(bot.id, topic.id, notification_level: TopicUser.notification_levels[:watching])
    post = Fabricate(:post, user: human, topic: topic)

    follow_up = Fabricate(:post, user: human, topic: topic)
    events =
      DiscourseEvent.track_events(:notification_created) do
        PostAlerter.post_created(post)
        PostAlerter.post_created(follow_up)
      end

    expect(
      events.filter_map do |event|
        event[:params].first.post_number if event[:params].first.user_id == bot.id
      end,
    ).to eq([post.post_number, follow_up.post_number])
  end
end
