# frozen_string_literal: true

RSpec::Matchers.define :add_notification do |user, notification_type|
  match(notify_expectation_failures: true) do |actual|
    notifications = user.notifications
    before = notifications.count

    actual.call

    expect(notifications.count).to eq(before + 1),
    "expected 1 new notification, got #{notifications.count - before}"

    last_notification_type = notifications.last.notification_type
    expect(last_notification_type).to eq(Notification.types[notification_type]),
    "expected notification type to be '#{notification_type}', got '#{Notification.types.key(last_notification_type)}'"
  end

  match_when_negated do |actual|
    expect { actual.call }.to_not change {
      user.notifications.where(notification_type: Notification.types[notification_type]).count
    }
  end

  supports_block_expectations
end

RSpec::Matchers.define_negated_matcher :not_add_notification, :add_notification

RSpec.describe PostAlerter do
  fab!(:category)

  fab!(:topic)
  fab!(:post)

  fab!(:private_message_topic)
  fab!(:private_message_topic_post1) { Fabricate(:post, topic: private_message_topic) }
  fab!(:private_message_topic_post2) { Fabricate(:post, topic: private_message_topic) }

  fab!(:group)

  fab!(:admin)
  fab!(:evil_trout) { Fabricate(:evil_trout, refresh_auto_groups: true) }
  fab!(:coding_horror)
  fab!(:walterwhite) { Fabricate(:walter_white, refresh_auto_groups: true) }
  fab!(:user)
  fab!(:tl2_user) { Fabricate(:user, trust_level: TrustLevel[2]) }

  fab!(:private_category) do
    Fabricate(
      :private_category,
      group: group,
      email_in: "test@test.com",
      email_in_allow_strangers: true,
    )
  end

  def create_post_with_alerts(args = {})
    post = Fabricate(:post, args)
    PostAlerter.post_created(post)
  end

  def setup_push_notification_subscription_for(user:)
    2.times do |i|
      client = Fabricate(:user_api_key_client, client_id: "xxx#{i}", application_name: "iPhone#{i}")
      Fabricate(
        :user_api_key,
        user: user,
        scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
        push_url: "https://site2.com/push",
        user_api_key_client_id: client.id,
      )
    end
  end

  context "with private message" do
    it "notifies for pms correctly" do
      pm = Fabricate(:topic, archetype: "private_message", category_id: nil)
      op = Fabricate(:post, user: pm.user)
      pm.allowed_users << pm.user
      PostAlerter.post_created(op)

      reply = Fabricate(:post, user: pm.user, topic: pm, reply_to_post_number: 1)
      PostAlerter.post_created(reply)

      reply2 = Fabricate(:post, topic: pm, reply_to_post_number: 1)
      PostAlerter.post_created(reply2)

      # we get a green notification for a reply
      expect(Notification.where(user_id: pm.user_id).pick(:notification_type)).to eq(
        Notification.types[:private_message],
      )

      TopicUser.change(
        pm.user_id,
        pm.id,
        notification_level: TopicUser.notification_levels[:tracking],
      )

      Notification.destroy_all

      reply3 = Fabricate(:post, topic: pm)
      PostAlerter.post_created(reply3)

      # no notification cause we are tracking
      expect(Notification.where(user_id: pm.user_id).count).to eq(0)

      Notification.destroy_all

      reply4 = Fabricate(:post, topic: pm, reply_to_post_number: 1)
      PostAlerter.post_created(reply4)

      # yes notification cause we were replied to
      expect(Notification.where(user_id: pm.user_id).count).to eq(1)
    end

    it "prioritises 'private_message' type even if direct mention" do
      pm = Fabricate(:topic, archetype: "private_message", category_id: nil)
      op =
        Fabricate(:post, topic: pm, user: pm.user, raw: "Hello @#{user.username}, nice to meet you")
      pm.allowed_users << pm.user
      pm.allowed_users << user
      TopicUser.create!(
        user_id: user.id,
        topic_id: pm.id,
        notification_level: TopicUser.notification_levels[:watching],
      )
      PostAlerter.post_created(op)

      expect(Notification.where(user_id: user.id).pick(:notification_type)).to eq(
        Notification.types[:private_message],
      )
    end

    context "with group inboxes" do
      fab!(:user1) { Fabricate(:user) }
      fab!(:user2) { Fabricate(:user) }
      fab!(:group) do
        Fabricate(:group, users: [user2], name: "TestGroup", default_notification_level: 2)
      end
      fab!(:watching_first_post_group) do
        Fabricate(
          :group,
          name: "some_group",
          users: [evil_trout, coding_horror],
          messageable_level: Group::ALIAS_LEVELS[:everyone],
          default_notification_level: NotificationLevels.all[:watching_first_post],
        )
      end
      fab!(:pm) do
        Fabricate(:topic, archetype: "private_message", category_id: nil, allowed_groups: [group])
      end
      fab!(:op) { Fabricate(:post, user: pm.user, topic: pm) }

      it "triggers :before_create_notifications_for_users" do
        pm.allowed_users << user1
        events = DiscourseEvent.track_events { PostAlerter.post_created(op) }

        expect(events).to include(
          event_name: :before_create_notifications_for_users,
          params: [[user1], op],
        )
        expect(events).to include(
          event_name: :before_create_notifications_for_users,
          params: [[user2], op],
        )
      end

      it "triggers group summary notification" do
        Jobs.run_immediately!
        TopicUser.change(
          user2.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        PostAlerter.post_created(op)
        group_summary_notification = Notification.where(user_id: user2.id)

        expect(group_summary_notification.count).to eq(1)
        expect(group_summary_notification.first.notification_type).to eq(
          Notification.types[:group_message_summary],
        )

        notification_payload = JSON.parse(group_summary_notification.first.data)
        expect(notification_payload["group_name"]).to eq(group.name)
        expect(notification_payload["inbox_count"]).to eq(1)

        # archiving the only PM clears the group summary notification
        GroupArchivedMessage.archive!(group.id, pm)
        expect(Notification.where(user_id: user2.id)).to be_blank

        # moving to inbox the only PM restores the group summary notification
        GroupArchivedMessage.move_to_inbox!(group.id, pm)
        group_summary_notification = Notification.where(user_id: user2.id)
        expect(group_summary_notification.first.notification_type).to eq(
          Notification.types[:group_message_summary],
        )

        updated_payload = JSON.parse(group_summary_notification.first.data)
        expect(updated_payload["group_name"]).to eq(group.name)
        expect(updated_payload["inbox_count"]).to eq(1)

        # adding a second PM updates the count
        pm2 =
          Fabricate(:topic, archetype: "private_message", category_id: nil, allowed_groups: [group])
        op2 = Fabricate(:post, user: pm2.user, topic: pm2)
        TopicUser.change(
          user2.id,
          pm2.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        PostAlerter.post_created(op2)
        group_summary_notification = Notification.where(user_id: user2.id)
        updated_payload = JSON.parse(group_summary_notification.first.data)

        expect(updated_payload["group_name"]).to eq(group.name)
        expect(updated_payload["inbox_count"]).to eq(2)

        # archiving the second PM quietly updates the group summary count for the acting user
        GroupArchivedMessage.archive!(group.id, pm2, acting_user_id: user2.id)
        group_summary_notification = Notification.where(user_id: user2.id)
        expect(group_summary_notification.first.read).to eq(true)
        updated_payload = JSON.parse(group_summary_notification.first.data)

        expect(updated_payload["inbox_count"]).to eq(1)

        # moving to inbox the second PM quietly updates the group summary count for the acting user
        GroupArchivedMessage.move_to_inbox!(group.id, pm2, acting_user_id: user2.id)
        group_summary_notification = Notification.where(user_id: user2.id)
        expect(group_summary_notification.first.read).to eq(true)
        updated_payload = JSON.parse(group_summary_notification.first.data)

        expect(updated_payload["group_name"]).to eq(group.name)
        expect(updated_payload["inbox_count"]).to eq(2)
      end

      it "updates the consolidated group summary inbox count and bumps the notification" do
        user2.update!(last_seen_at: 5.minutes.ago)
        TopicUser.change(
          user2.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        PostAlerter.post_created(op)

        starting_count =
          Notification
            .where(user_id: user2.id, notification_type: Notification.types[:group_message_summary])
            .pluck("data::json ->> 'inbox_count'")
            .last
            .to_i

        another_pm =
          Fabricate(:topic, archetype: "private_message", category_id: nil, allowed_groups: [group])
        another_post = Fabricate(:post, user: another_pm.user, topic: another_pm)
        TopicUser.change(
          user2.id,
          another_pm.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        message_data =
          MessageBus
            .track_publish("/notification/#{user2.id}") { PostAlerter.post_created(another_post) }
            .first
            .data

        expect(Notification.where(user: user2).count).to eq(1)
        expect(message_data.dig(:last_notification, :notification, :data, :inbox_count)).to eq(
          starting_count + 1,
        )
        expect(message_data[:unread_notifications]).to eq(1)
      end

      it "sends a PM notification when replying to a member tracking the topic" do
        group.add(user1)

        post = Fabricate(:post, topic: pm, user: user1)
        TopicUser.change(
          user1.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        expect {
          create_post_with_alerts(
            raw: "this is a reply to your post...",
            topic: pm,
            user: user2,
            reply_to_post_number: post.post_number,
          )
        }.to change(
          user1.notifications.where(notification_type: Notification.types[:private_message]),
          :count,
        ).by(1)
      end

      it "notifies a group member if someone replies to their post" do
        group.add(user1)

        post = Fabricate(:post, topic: pm, user: user1)
        TopicUser.change(
          user1.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:regular],
        )

        expect {
          create_post_with_alerts(
            raw: "this is a reply to your post...",
            topic: pm,
            user: user2,
            reply_to_post_number: post.post_number,
          )
        }.to change(user1.notifications, :count).by(1)
      end

      it "notifies a group member if someone quotes their post" do
        group.add(user1)

        post = Fabricate(:post, topic: pm, user: user1)
        TopicUser.change(
          user1.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:regular],
        )
        quote_raw = <<~MD
          [quote="#{user1.username}, post:1, topic:#{pm.id}"]#{post.raw}[/quote]
        MD

        expect { create_post_with_alerts(raw: quote_raw, topic: pm, user: user2) }.to change(
          user1.notifications,
          :count,
        ).by(1)
      end

      it "Doesn't notify non-admin users when their post is quoted inside a whisper" do
        group.add(admin)

        TopicUser.change(
          user2.id,
          pm.id,
          notification_level: TopicUser.notification_levels[:regular],
        )
        quote_raw = <<~MD
          [quote="#{user2.username}, post:1, topic:#{pm.id}"]#{op.raw}[/quote]
        MD

        expect {
          create_post_with_alerts(
            raw: quote_raw,
            topic: pm,
            user: admin,
            post_type: Post.types[:whisper],
          )
        }.not_to change(user2.notifications, :count)
      end

      context "with watching_first_post notification level" do
        it "notifies group members of first post" do
          post =
            PostCreator.create!(
              user,
              title: "Hi there, welcome to my topic",
              raw: "This is my awesome message",
              archetype: Archetype.private_message,
              target_group_names: watching_first_post_group.name,
            )

          PostAlerter.new.after_save_post(post, true)

          expect(
            evil_trout
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(1)
          expect(
            coding_horror
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(1)
        end

        it "doesn't notify group members of replies" do
          post =
            PostCreator.create!(
              user,
              title: "Hi there, welcome to my topic",
              raw: "This is my awesome message",
              archetype: Archetype.private_message,
              target_group_names: watching_first_post_group.name,
            )

          expect(
            evil_trout
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(0)
          expect(
            coding_horror
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(0)

          PostAlerter.new.after_save_post(post, true)

          expect(
            evil_trout
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(1)
          expect(
            coding_horror
              .notifications
              .where(notification_type: Notification.types[:private_message])
              .count,
          ).to eq(1)

          reply =
            Fabricate(
              :post,
              raw: "Reply to PM",
              user: user,
              topic: post.topic,
              reply_to_post_number: post.post_number,
            )

          expect do PostAlerter.new.after_save_post(reply, false) end.to_not change {
            Notification.count
          }
        end
      end
    end
  end

  context "with unread" do
    it "does not return whispers as unread posts" do
      _whisper =
        Fabricate(
          :post,
          raw: "this is a whisper post",
          user: admin,
          topic: post.topic,
          reply_to_post_number: post.post_number,
          post_type: Post.types[:whisper],
        )

      expect(PostAlerter.new.first_unread_post(post.user, post.topic)).to be_blank
    end
  end

  context "with edits" do
    it "notifies correctly on edits" do
      Jobs.run_immediately!
      PostActionNotifier.enable

      post = Fabricate(:post, raw: "I love waffles")

      expect do post.revise(admin, raw: "I made a revision") end.to add_notification(
        post.user,
        :edited,
      )

      # lets also like this post which should trigger a notification
      expect do
        PostActionCreator.new(admin, post, PostActionType.types[:like]).perform
      end.to add_notification(post.user, :liked)

      # skip this notification cause we already notified on an edit by the same user
      # in the previous edit
      freeze_time 2.hours.from_now

      expect do post.revise(admin, raw: "I made another revision") end.to_not change {
        Notification.count
      }

      # this we do not skip cause 1 day has passed
      freeze_time 23.hours.from_now

      expect do post.revise(admin, raw: "I made another revision xyz") end.to add_notification(
        post.user,
        :edited,
      )

      expect do post.revise(Fabricate(:admin), raw: "I made a revision") end.to add_notification(
        post.user,
        :edited,
      )

      freeze_time 2.hours.from_now

      expect do post.revise(admin, raw: "I made another revision") end.to add_notification(
        post.user,
        :edited,
      )
    end

    it "notifies flaggers when flagged post gets unhidden by edit" do
      post = create_post

      PostActionNotifier.enable
      Reviewable.set_priorities(high: 4.0)
      SiteSetting.hide_post_sensitivity = Reviewable.sensitivities[:low]

      PostActionCreator.spam(evil_trout, post)
      PostActionCreator.spam(walterwhite, post)

      post.reload
      expect(post.hidden).to eq(true)

      expect { post.revise(post.user, raw: post.raw + " ha I edited it ") }.to add_notification(
        evil_trout,
        :edited,
      ).and add_notification(walterwhite, :edited)

      post.reload
      expect(post.hidden).to eq(false)

      notification = walterwhite.notifications.last
      expect(notification.topic_id).to eq(post.topic.id)
      expect(notification.post_number).to eq(post.post_number)
      expect(notification.data_hash["display_username"]).to eq(post.user.username)

      PostActionCreator.create(coding_horror, post, :spam)
      PostActionCreator.create(walterwhite, post, :off_topic)

      post.reload
      expect(post.hidden).to eq(true)

      expect {
        post.revise(post.user, raw: post.raw + " ha I edited it again ")
      }.to not_add_notification(evil_trout, :edited).and not_add_notification(
              coding_horror,
              :edited,
            ).and not_add_notification(walterwhite, :edited)
    end
  end

  context "with quotes" do
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }

    it "does not notify for muted users" do
      post = Fabricate(:post, raw: '[quote="Eviltrout, post:1"]whatup[/quote]', topic: topic)
      MutedUser.create!(user_id: evil_trout.id, muted_user_id: post.user_id)

      expect { PostAlerter.post_created(post) }.not_to change(evil_trout.notifications, :count)
    end

    it "does not notify for ignored users" do
      post = Fabricate(:post, raw: '[quote="EvilTrout, post:1"]whatup[/quote]', topic: topic)
      Fabricate(:ignored_user, user: evil_trout, ignored_user: post.user)

      expect { PostAlerter.post_created(post) }.not_to change(evil_trout.notifications, :count)
    end

    it "does not notify for users with new reply notification" do
      post = Fabricate(:post, raw: '[quote="eviltRout, post:1"]whatup[/quote]', topic: topic)
      notification =
        Notification.create!(
          topic: post.topic,
          post_number: post.post_number,
          read: false,
          notification_type: Notification.types[:replied],
          user: evil_trout,
          data: { topic_title: "test topic" }.to_json,
        )
      expect { PostAlerter.post_edited(post) }.not_to change(evil_trout.notifications, :count)

      notification.destroy
      expect { PostAlerter.post_edited(post) }.to change(evil_trout.notifications, :count).by(1)
    end

    it "does not collapse quote notifications" do
      expect {
        2.times do
          create_post_with_alerts(raw: '[quote="eviltrout, post:1"]whatup[/quote]', topic: topic)
        end
      }.to change(evil_trout.notifications, :count).by(2)
    end

    it "won't notify the user a second time on revision" do
      p1 = create_post_with_alerts(raw: '[quote="Evil Trout, post:1"]whatup[/quote]')
      expect {
        p1.revise(p1.user, raw: '[quote="Evil Trout, post:1"]whatup now?[/quote]')
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the poster" do
      topic = create_post_with_alerts.topic
      expect {
        Fabricate(
          :post,
          topic: topic,
          user: topic.user,
          raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]',
        )
      }.not_to change(topic.user.notifications, :count)
    end

    it "triggers :before_create_notifications_for_users" do
      post = Fabricate(:post, raw: '[quote="eviltrout, post:1"]whatup[/quote]')
      events = DiscourseEvent.track_events { PostAlerter.post_created(post) }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[evil_trout], post],
      )
    end

    context "with notifications when prioritizing full names" do
      before do
        SiteSetting.prioritize_username_in_ux = false
        SiteSetting.display_name_on_posts = true
      end

      it "sends to correct user" do
        quote = <<~MD
          [quote="#{evil_trout.name}, post:1, username:#{evil_trout.username}"]whatup[/quote]
        MD

        expect { create_post_with_alerts(raw: quote, topic: topic) }.to change(
          evil_trout.notifications,
          :count,
        ).by(1)
      end

      it "sends to correct users when nested quotes with multiple users" do
        quote = <<~MD
          [quote="#{evil_trout.name}, post:1, username:#{evil_trout.username}"]this [quote="#{walterwhite.name}, post:2, username:#{walterwhite.username}"]whatup[/quote][/quote]
        MD

        expect { create_post_with_alerts(raw: quote, topic: topic) }.to change(
          evil_trout.notifications,
          :count,
        ).by(1).and change(walterwhite.notifications, :count).by(1)
      end

      it "sends to correct users when multiple quotes" do
        user = Fabricate(:user)
        quote = <<~MD
          [quote="#{evil_trout.name}, post:1, username:#{evil_trout.username}"]"username:#{user.username}" [/quote]/n [quote="#{walterwhite.name}, post:2, username:#{walterwhite.username}"]whatup[/quote]
        MD

        expect { create_post_with_alerts(raw: quote, topic: topic) }.to change(
          evil_trout.notifications,
          :count,
        ).by(1).and change(walterwhite.notifications, :count).by(1).and not_change(
                      user.notifications,
                      :count,
                    )
      end

      it "sends to correct user when user has a full name that matches another user's username" do
        user_with_matching_full_name = Fabricate(:user, name: evil_trout.username)
        quote = <<~MD
          [quote="#{user_with_matching_full_name.name}, post:1, username:#{user_with_matching_full_name.username}"]this [/quote]
        MD

        expect { create_post_with_alerts(raw: quote, topic: topic) }.to change(
          user_with_matching_full_name.notifications,
          :count,
        ).by(1).and not_change(evil_trout.notifications, :count)
      end
    end
  end

  context "with linked" do
    let(:post1) { create_post }
    let(:user) { post1.user }
    let(:linking_post) { create_post(raw: "my magic topic\n##{Discourse.base_url}#{post1.url}") }

    before { Jobs.run_immediately! }

    it "will notify correctly on linking" do
      linking_post

      expect(user.notifications.count).to eq(1)

      watcher = Fabricate(:user)
      TopicUser.create!(
        user_id: watcher.id,
        topic_id: topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      create_post(
        topic_id: topic.id,
        user: user,
        raw: "my magic topic\n##{Discourse.base_url}#{post1.url}",
      )

      user.reload
      expect(user.notifications.where(notification_type: Notification.types[:linked]).count).to eq(
        1,
      )

      expect(watcher.notifications.count).to eq(1)

      # don't notify on reflection
      post1.reload
      expect(PostAlerter.new.extract_linked_users(post1).length).to eq(0)
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events { linking_post }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[user], linking_post],
      )
    end

    it "doesn't notify the linked user if the user is staged and the category is restricted and allows strangers" do
      staged_user = Fabricate(:staged, refresh_auto_groups: true)
      group_member = Fabricate(:user, refresh_auto_groups: true)
      group.add(group_member)

      staged_user_post = create_post(user: staged_user, category: private_category)

      create_post(
        user: group_member,
        category: private_category,
        raw: "my magic topic\n##{Discourse.base_url}#{staged_user_post.url}",
      )

      staged_user.reload
      expect(
        staged_user.notifications.where(notification_type: Notification.types[:linked]).count,
      ).to eq(0)
    end
  end

  context "with @here" do
    let(:post) do
      create_post_with_alerts(raw: "Hello @here how are you?", user: tl2_user, topic: topic)
    end
    fab!(:other_post) { Fabricate(:post, topic: topic) }

    before { Jobs.run_immediately! }

    it "does not notify unrelated users" do
      expect { post }.not_to change(evil_trout.notifications, :count)
    end

    it "does not work if user here exists" do
      Fabricate(:user, username: SiteSetting.here_mention)
      expect { post }.not_to change(other_post.user.notifications, :count)
    end

    it "notifies users who replied" do
      post2 = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      post3 = Fabricate(:post, topic: topic)

      expect { post }.to change(other_post.user.notifications, :count).by(1).and not_change(
              post2.user.notifications,
              :count,
            ).and change(post3.user.notifications, :count).by(1)
    end

    it "notifies users who whispered" do
      post2 = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      post3 = Fabricate(:post, topic: topic)

      tl2_user.grant_admin!

      expect { post }.to change(other_post.user.notifications, :count).by(1).and change(
              post2.user.notifications,
              :count,
            ).by(1).and change(post3.user.notifications, :count).by(1)
    end

    it "notifies only last max_here_mentioned users" do
      SiteSetting.max_here_mentioned = 2
      3.times { Fabricate(:post, topic: topic) }
      expect { post }.to change { Notification.count }.by(2)
    end
  end

  context "with @group mentions" do
    fab!(:group) do
      Fabricate(:group, name: "group", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    end
    let(:post) { create_post_with_alerts(raw: "Hello @group how are you?") }
    before { group.add(evil_trout) }

    it "notifies users correctly" do
      expect { post }.to change(evil_trout.notifications, :count).by(1)

      expect(GroupMention.count).to eq(1)

      Fabricate(:group, name: "group-alt", mentionable_level: Group::ALIAS_LEVELS[:everyone])

      expect {
        create_post_with_alerts(raw: "Hello, @group-alt should not trigger a notification?")
      }.not_to change(evil_trout.notifications, :count)

      expect(GroupMention.count).to eq(2)

      group.update_columns(mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins])
      expect { create_post_with_alerts(raw: "Hello @group you are not mentionable") }.not_to change(
        evil_trout.notifications,
        :count,
      )

      expect(GroupMention.count).to eq(3)

      group.update_columns(mentionable_level: Group::ALIAS_LEVELS[:owners_mods_and_admins])
      group.add_owner(user)
      expect {
        create_post_with_alerts(raw: "Hello @group the owner can mention you", user: user)
      }.to change(evil_trout.notifications, :count).by(1)

      expect(GroupMention.count).to eq(4)
    end

    it "takes private mention as precedence" do
      expect {
        create_post_with_alerts(raw: "Hello @group and @eviltrout, nice to meet you")
      }.to change(evil_trout.notifications, :count).by(1)
      expect(evil_trout.notifications.last.notification_type).to eq(Notification.types[:mentioned])
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events { post }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[evil_trout], post],
      )
    end
  end

  context "with @mentions" do
    let(:mention_post) { create_post_with_alerts(user: user, raw: "Hello @eviltrout") }
    let(:topic) { mention_post.topic }

    before { Jobs.run_immediately! }

    it "notifies a user" do
      expect { mention_post }.to change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      expect {
        mention_post.revise(
          mention_post.user,
          raw: "New raw content that still mentions @eviltrout",
        )
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      expect {
        create_post_with_alerts(user: user, raw: "second post", topic: topic)
      }.not_to change(user.notifications, :count)
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events { mention_post }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[evil_trout], mention_post],
      )
    end

    it "notification comes from editor if mention is added later" do
      post = create_post_with_alerts(user: user, raw: "No mention here.")
      expect { post.revise(admin, raw: "Mention @eviltrout in this edit.") }.to change(
        evil_trout.notifications,
        :count,
      )
      n = evil_trout.notifications.last
      expect(n.data_hash["original_username"]).to eq(admin.username)
    end

    it "doesn't notify the last post editor if they mention themselves" do
      post = create_post_with_alerts(user: user, raw: "Post without a mention.")
      expect { post.revise(evil_trout, raw: "O hai, @eviltrout!") }.not_to change(
        evil_trout.notifications,
        :count,
      )
    end

    fab!(:alice) { Fabricate(:user, username: "alice") }
    fab!(:bob) { Fabricate(:user, username: "bob") }
    fab!(:carol) { Fabricate(:admin, username: "carol") }
    fab!(:dave) { Fabricate(:user, username: "dave") }
    fab!(:eve) { Fabricate(:user, username: "eve") }
    fab!(:group) do
      Fabricate(:group, name: "group", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    end

    before { group.bulk_add([alice.id, eve.id]) }

    def create_post_with_alerts(args = {})
      post = Fabricate(:post, args)
      PostAlerter.post_created(post)
    end

    def set_topic_notification_level(user, topic, level_name)
      TopicUser.change(
        user.id,
        topic.id,
        notification_level: TopicUser.notification_levels[level_name],
      )
    end

    context "with topic" do
      fab!(:topic) { Fabricate(:topic, user: alice) }

      %i[watching tracking regular].each do |notification_level|
        context "when notification level is '#{notification_level}'" do
          before { set_topic_notification_level(alice, topic, notification_level) }

          it "notifies about @username mention" do
            args = { user: bob, topic: topic, raw: "Hello @alice" }
            expect { create_post_with_alerts(args) }.to add_notification(alice, :mentioned)
          end
        end
      end

      context "when notification level is 'muted'" do
        before { set_topic_notification_level(alice, topic, :muted) }

        it "does not notify about @username mention" do
          args = { user: bob, topic: topic, raw: "Hello @alice" }
          expect { create_post_with_alerts(args) }.to_not add_notification(alice, :mentioned)
        end
      end
    end

    context "with message to users" do
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: alice,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: alice),
            Fabricate.build(:topic_allowed_user, user: bob),
            Fabricate.build(:topic_allowed_user, user: Discourse.system_user),
          ],
        )
      end

      context "when user is part of conversation" do
        %i[watching tracking regular].each do |notification_level|
          context "when notification level is '#{notification_level}'" do
            before { set_topic_notification_level(alice, pm_topic, notification_level) }
            let(:expected_notification) do
              notification_level == :watching ? :private_message : :mentioned
            end

            it "notifies about @username mention" do
              args = { user: bob, topic: pm_topic, raw: "Hello @alice" }
              expect { create_post_with_alerts(args) }.to add_notification(
                alice,
                expected_notification,
              )
            end

            it "notifies about @username mentions by non-human users" do
              args = { user: Discourse.system_user, topic: pm_topic, raw: "Hello @alice" }
              expect { create_post_with_alerts(args) }.to add_notification(
                alice,
                expected_notification,
              )
            end

            it "notifies about @group mention when allowed user is part of group" do
              args = { user: bob, topic: pm_topic, raw: "Hello @group" }
              expect { create_post_with_alerts(args) }.to add_notification(alice, :group_mentioned)
            end
          end
        end

        context "when notification level is 'muted'" do
          before { set_topic_notification_level(alice, pm_topic, :muted) }

          it "does not notify about @username mention" do
            args = { user: bob, topic: pm_topic, raw: "Hello @alice" }
            expect { create_post_with_alerts(args) }.to_not add_notification(alice, :mentioned)
          end
        end
      end

      context "when user is not part of conversation" do
        it "does not notify about @username mention even though mentioned user is an admin" do
          args = { user: bob, topic: pm_topic, raw: "Hello @carol" }
          expect { create_post_with_alerts(args) }.to_not add_notification(carol, :mentioned)
        end

        it "does not notify about @username mention by non-human user even though mentioned user is an admin" do
          args = { user: Discourse.system_user, topic: pm_topic, raw: "Hello @carol" }
          expect { create_post_with_alerts(args) }.to_not add_notification(carol, :mentioned)
        end

        it "does not notify about @username mention when mentioned user is not allowed to see message" do
          args = { user: bob, topic: pm_topic, raw: "Hello @dave" }
          expect { create_post_with_alerts(args) }.to_not add_notification(dave, :mentioned)
        end

        it "does not notify about @group mention when user is not an allowed user" do
          args = { user: bob, topic: pm_topic, raw: "Hello @group" }
          expect { create_post_with_alerts(args) }.to_not add_notification(eve, :group_mentioned)
        end
      end
    end

    context "with message to group" do
      fab!(:some_group) do
        Fabricate(:group, name: "some_group", mentionable_level: Group::ALIAS_LEVELS[:everyone])
      end
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: alice,
          topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: Discourse.system_user)],
        )
      end

      before { some_group.bulk_add([alice.id, carol.id]) }

      context "when group is part of conversation" do
        %i[watching tracking regular].each do |notification_level|
          context "when notification level is '#{notification_level}'" do
            before { set_topic_notification_level(alice, pm_topic, notification_level) }

            it "notifies about @group mention" do
              args = { user: bob, topic: pm_topic, raw: "Hello @group" }
              expect { create_post_with_alerts(args) }.to add_notification(alice, :group_mentioned)
            end

            it "notifies about @group mentions by non-human users" do
              args = { user: Discourse.system_user, topic: pm_topic, raw: "Hello @group" }
              expect { create_post_with_alerts(args) }.to add_notification(alice, :group_mentioned)
            end

            it "notifies about @username mention when user belongs to allowed group" do
              args = { user: bob, topic: pm_topic, raw: "Hello @alice" }
              expect { create_post_with_alerts(args) }.to add_notification(alice, :mentioned)
            end
          end
        end

        context "when notification level is 'muted'" do
          before { set_topic_notification_level(alice, pm_topic, :muted) }

          it "does not notify about @group mention" do
            args = { user: bob, topic: pm_topic, raw: "Hello @group" }
            expect { create_post_with_alerts(args) }.to_not add_notification(
              alice,
              :group_mentioned,
            )
          end
        end
      end

      context "when group is not part of conversation" do
        it "does not notify about @group mention even though mentioned user is an admin" do
          args = { user: bob, topic: pm_topic, raw: "Hello @some_group" }
          expect { create_post_with_alerts(args) }.to_not add_notification(carol, :group_mentioned)
        end

        it "does not notify about @group mention by non-human user even though mentioned user is an admin" do
          args = { user: Discourse.system_user, topic: pm_topic, raw: "Hello @some_group" }
          expect { create_post_with_alerts(args) }.to_not add_notification(carol, :group_mentioned)
        end

        it "does not notify about @username mention when user doesn't belong to allowed group" do
          args = { user: bob, topic: pm_topic, raw: "Hello @dave" }
          expect { create_post_with_alerts(args) }.to_not add_notification(dave, :mentioned)
        end
      end
    end
  end

  describe ".create_notification" do
    fab!(:topic) { Fabricate(:private_message_topic, user: user, created_at: 1.hour.ago) }
    fab!(:post) { Fabricate(:post, topic: topic, created_at: 1.hour.ago) }
    let(:type) { Notification.types[:private_message] }

    it "creates a notification for PMs" do
      post.revise(user, { raw: "This is the revised post" }, revised_at: Time.zone.now)

      expect { PostAlerter.new.create_notification(user, type, post) }.to change {
        user.notifications.count
      }.by(1)

      expect(user.notifications.last.data_hash["topic_title"]).to eq(topic.title)
    end

    it "keeps the original title for PMs" do
      original_title = topic.title

      post.revise(user, { title: "This is the revised title" }, revised_at: Time.now)

      expect { PostAlerter.new.create_notification(user, type, post) }.to change {
        user.notifications.count
      }.by(1)

      expect(user.notifications.last.data_hash["topic_title"]).to eq(original_title)
    end

    it "triggers :pre_notification_alert" do
      events = DiscourseEvent.track_events { PostAlerter.new.create_notification(user, type, post) }

      payload = {
        notification_type: type,
        post_number: post.post_number,
        topic_title: post.topic.title,
        topic_id: post.topic.id,
        excerpt: post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true),
        username: post.username,
        post_url: post.url,
      }

      expect(events).to include(event_name: :pre_notification_alert, params: [user, payload])
    end

    it "does not alert when revising and changing notification type" do
      PostAlerter.new.create_notification(user, type, post)

      post.revise(
        user,
        { raw: "Editing post to fake include a mention of @eviltrout" },
        revised_at: Time.now,
      )

      events =
        DiscourseEvent.track_events do
          PostAlerter.new.create_notification(user, Notification.types[:mentioned], post)
        end

      payload = {
        notification_type: type,
        post_number: post.post_number,
        topic_title: post.topic.title,
        topic_id: post.topic.id,
        excerpt: post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true),
        username: post.username,
        post_url: post.url,
      }

      expect(events).not_to include(event_name: :pre_notification_alert, params: [user, payload])
    end

    it "triggers :before_create_notification" do
      type = Notification.types[:private_message]
      events =
        DiscourseEvent.track_events do
          PostAlerter.new.create_notification(user, type, post, { revision_number: 1 })
        end
      expect(events).to include(
        event_name: :before_create_notification,
        params: [user, type, post, { revision_number: 1 }],
      )
    end

    it "applies modifiers to notification_data" do
      Plugin::Instance
        .new
        .register_modifier(:notification_data) do |notification_data|
          notification_data[:silly_key] = "silly value"
          notification_data
        end

      notification = PostAlerter.new.create_notification(user, type, post)
      expect(notification.data_hash[:silly_key]).to eq("silly value")

      DiscoursePluginRegistry.clear_modifiers!
    end
  end

  describe ".push_notification" do
    let(:mention_post) { create_post_with_alerts(user: user, raw: "Hello @eviltrout :heart:") }
    let(:topic) { mention_post.topic }

    before do
      SiteSetting.allowed_user_api_push_urls = "https://site.com/push|https://site2.com/push"
      setup_push_notification_subscription_for(user: evil_trout)
    end

    describe "DiscoursePluginRegistry#push_notification_filters" do
      after { DiscoursePluginRegistry.reset_register!(:push_notification_filters) }

      it "sends push notifications when all filters pass" do
        evil_trout.update!(last_seen_at: 10.minutes.ago)
        Plugin::Instance.new.register_push_notification_filter { |user, payload| true }

        alerts =
          MessageBus.track_publish("/notification-alert/#{evil_trout.id}") do
            expect { mention_post }.to change { Jobs::PushNotification.jobs.count }.by(1)
          end

        expect(alerts).not_to be_empty
      end

      it "does not send push notifications when a filters returns false" do
        Plugin::Instance.new.register_push_notification_filter { |user, payload| false }

        alerts =
          MessageBus.track_publish("/notification-alert/#{evil_trout.id}") do
            expect { mention_post }.not_to change { Jobs::PushNotification.jobs.count }
          end

        expect(alerts).to be_empty
      end
    end

    it "triggers the push notification event" do
      events = DiscourseEvent.track_events { mention_post }

      push_notification_event = events.find { |event| event[:event_name] == :push_notification }
      expect(push_notification_event).to be_present
      expect(push_notification_event[:params][0].username).to eq("eviltrout")
      expect(push_notification_event[:params][1][:username]).to eq(user.username)
      expect(push_notification_event[:params][1][:excerpt]).to eq("Hello @eviltrout ❤")
    end

    it "pushes nothing to suspended users" do
      evil_trout.update_columns(suspended_till: 1.year.from_now)
      expect { mention_post }.to_not change { Jobs::PushNotification.jobs.count }

      events = DiscourseEvent.track_events { mention_post }
      expect(events.find { |event| event[:event_name] == :push_notification }).not_to be_present
    end

    it "pushes nothing when the user is in 'do not disturb'" do
      Fabricate(
        :do_not_disturb_timing,
        user: evil_trout,
        starts_at: Time.zone.now,
        ends_at: 1.day.from_now,
      )

      expect { mention_post }.to_not change { Jobs::PushNotification.jobs.count }

      events = DiscourseEvent.track_events { mention_post }
      expect(events.find { |event| event[:event_name] == :push_notification }).not_to be_present
    end

    it "correctly pushes notifications if configured correctly" do
      Jobs.run_immediately!
      body = nil
      headers = nil

      stub_request(:post, "https://site2.com/push").to_return do |request|
        body = request.body
        headers = request.headers
        { status: 200, body: "OK" }
      end

      set_subfolder "/subpath"
      payload = {
        "secret_key" => SiteSetting.push_api_secret_key,
        "url" => Discourse.base_url,
        "title" => SiteSetting.title,
        "description" => SiteSetting.site_description,
        "notifications" => [
          {
            "notification_type" => 1,
            "post_number" => 1,
            "topic_title" => topic.title,
            "topic_id" => topic.id,
            "excerpt" => "Hello @eviltrout ❤",
            "username" => user.username,
            "url" => UrlHelper.absolute(Discourse.base_path + mention_post.url),
            "client_id" => "xxx0",
          },
          {
            "notification_type" => 1,
            "post_number" => 1,
            "topic_title" => topic.title,
            "topic_id" => topic.id,
            "excerpt" => "Hello @eviltrout ❤",
            "username" => user.username,
            "url" => UrlHelper.absolute(Discourse.base_path + mention_post.url),
            "client_id" => "xxx1",
          },
        ],
      }

      post = mention_post

      expect(JSON.parse(body)).to eq(payload)
      expect(headers["Content-Type"]).to eq("application/json")

      TopicUser.change(
        evil_trout.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      post = Fabricate(:post, topic: post.topic, user_id: evil_trout.id)
      user2 = Fabricate(:user)

      # if we collapse a reply notification we should get notified on the correct post
      new_post =
        create_post_with_alerts(
          topic: post.topic,
          user_id: user.id,
          reply_to_post_number: post.post_number,
          raw: "this is my first reply",
        )

      changes = {
        "notification_type" => Notification.types[:posted],
        "post_number" => new_post.post_number,
        "username" => new_post.user.username,
        "excerpt" => new_post.raw,
        "url" => UrlHelper.absolute(Discourse.base_path + new_post.url),
      }

      payload["notifications"][0].merge! changes
      payload["notifications"][1].merge! changes

      expect(JSON.parse(body)).to eq(payload)

      new_post =
        create_post_with_alerts(
          topic: post.topic,
          user_id: user2.id,
          reply_to_post_number: post.post_number,
          raw: "this is my second reply",
        )

      changes = {
        "post_number" => new_post.post_number,
        "username" => new_post.user.username,
        "excerpt" => new_post.raw,
        "url" => UrlHelper.absolute(Discourse.base_path + new_post.url),
      }

      payload["notifications"][0].merge! changes
      payload["notifications"][1].merge! changes

      expect(JSON.parse(body)).to eq(payload)
    end

    it "does not have invalid HTML in the excerpt" do
      Fabricate(:category, slug: "random")
      Jobs.run_immediately!
      body = nil

      stub_request(:post, "https://site2.com/push").to_return do |request|
        body = request.body
        { status: 200, body: "OK" }
      end
      create_post_with_alerts(user: user, raw: "this, @eviltrout, is a test with #random")
      expect(JSON.parse(body)["notifications"][0]["excerpt"]).to eq(
        "this, @eviltrout, is a test with #random",
      )
    end

    it "delays push notification for active online user" do
      SiteSetting.push_notification_time_window_mins = 10
      evil_trout.update!(last_seen_at: 5.minutes.ago)

      expect { mention_post }.to change { Jobs::PushNotification.jobs.count }
      expect(Jobs::PushNotification.jobs[0]["at"]).to be_within(30.second).of(
        5.minutes.from_now.to_f,
      )
    end

    context "with push subscriptions" do
      before do
        Fabricate(:push_subscription, user: evil_trout)
        SiteSetting.push_notification_time_window_mins = 10
      end

      it "delays sending push notification for active online user" do
        evil_trout.update!(last_seen_at: 5.minutes.ago)

        expect { mention_post }.to change { Jobs::SendPushNotification.jobs.count }
        expect(Jobs::SendPushNotification.jobs[0]["at"]).not_to be_nil
      end

      it "delays sending push notification for active online user for the correct delay ammount" do
        evil_trout.update!(last_seen_at: 5.minutes.ago)

        # SiteSetting.push_notification_time_window_mins is 10
        # last_seen_at is 5 minutes ago
        # 10 minutes from now - 5 minutes ago = 5 minutes
        delay = 5.minutes.from_now.to_f

        expect { mention_post }.to change { Jobs::SendPushNotification.jobs.count }
        expect(Jobs::SendPushNotification.jobs[0]["at"]).to be_within(30.second).of(delay)
      end

      it "does not delay push notification for inactive offline user" do
        evil_trout.update!(last_seen_at: 40.minutes.ago)

        expect { mention_post }.to change { Jobs::SendPushNotification.jobs.count }
        expect(Jobs::SendPushNotification.jobs[0]["at"]).to be_nil
      end
    end
  end

  describe ".create_notification_alert" do
    before { evil_trout.update_columns(last_seen_at: 10.minutes.ago) }

    it "publishes notification to notification-alert MessageBus channel" do
      messages =
        MessageBus.track_publish("/notification-alert/#{evil_trout.id}") do
          PostAlerter.create_notification_alert(
            user: evil_trout,
            post: post,
            notification_type: Notification.types[:mentioned],
            excerpt: "excerpt",
            username: "username",
          )
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:username]).to eq("username")
      expect(messages.first.data[:post_url]).to eq(post.url)
    end

    let(:modifier_block) do
      Proc.new do |payload|
        payload[:username] = "gotcha"
        payload[:post_url] = "stolen_url"
        payload
      end
    end

    it "applies the post_alerter_live_notification_payload modifier" do
      plugin_instance = Plugin::Instance.new
      plugin_instance.register_modifier(:post_alerter_live_notification_payload, &modifier_block)

      messages =
        MessageBus.track_publish("/notification-alert/#{evil_trout.id}") do
          PostAlerter.create_notification_alert(
            user: evil_trout,
            post: post,
            notification_type: Notification.types[:mentioned],
            excerpt: "excerpt",
            username: "username",
          )
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:username]).to eq("gotcha")
      expect(messages.first.data[:post_url]).to eq("stolen_url")
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :post_alerter_live_notification_payload,
        &modifier_block
      )
    end

    it "does nothing for suspended users" do
      evil_trout.update_columns(suspended_till: 1.year.from_now)

      events = nil
      messages =
        MessageBus.track_publish do
          events =
            DiscourseEvent.track_events do
              PostAlerter.create_notification_alert(
                user: evil_trout,
                post: post,
                notification_type: Notification.types[:custom],
                excerpt: "excerpt",
                username: "username",
              )
            end
        end

      expect(events.size).to eq(0)
      expect(messages.size).to eq(0)
      expect(Jobs::PushNotification.jobs.size).to eq(0)
    end

    it "does not publish to MessageBus /notification-alert if the user has not been seen for > 30 days, but still sends a push notification" do
      evil_trout.update_columns(last_seen_at: 31.days.ago)

      SiteSetting.allowed_user_api_push_urls = "https://site2.com/push"
      Fabricate(
        :user_api_key,
        user: evil_trout,
        scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
        push_url: "https://site2.com/push",
      )

      events = nil
      messages =
        MessageBus.track_publish do
          events =
            DiscourseEvent.track_events do
              PostAlerter.create_notification_alert(
                user: evil_trout,
                post: post,
                notification_type: Notification.types[:custom],
                excerpt: "excerpt",
                username: "username",
              )
            end
        end

      expect(events.map { |event| event[:event_name] }).to include(
        :pre_notification_alert,
        :push_notification,
        :post_notification_alert,
      )
      expect(messages.size).to eq(0)
      expect(Jobs::PushNotification.jobs.size).to eq(1)
    end
  end

  describe "watching_first_post" do
    fab!(:user)
    fab!(:category)
    fab!(:tag)
    fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "doesn't notify people who aren't watching" do
      PostAlerter.post_created(post)
      expect(
        user.notifications.where(notification_type: Notification.types[:watching_first_post]).count,
      ).to eq(0)
    end

    it "notifies the user who is following the first post category" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      PostAlerter.new.after_save_post(post, true)
      expect(
        user.notifications.where(notification_type: Notification.types[:watching_first_post]).count,
      ).to eq(1)
    end

    it "doesn't notify when the record is not new" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      PostAlerter.new.after_save_post(post, false)
      expect(
        user.notifications.where(notification_type: Notification.types[:watching_first_post]).count,
      ).to eq(0)
    end

    it "notifies the user who is following the first post tag" do
      level = TagUser.notification_levels[:watching_first_post]
      TagUser.change(user.id, tag.id, level)
      PostAlerter.post_created(post)
      expect(
        user.notifications.where(notification_type: Notification.types[:watching_first_post]).count,
      ).to eq(1)
    end

    it "notifies the user who is following the first post group" do
      GroupUser.create(group_id: group.id, user_id: user.id)
      GroupUser.create(group_id: group.id, user_id: post.user.id)
      topic.topic_allowed_groups.create(group_id: group.id)

      level = GroupUser.notification_levels[:watching_first_post]
      GroupUser.where(user_id: user.id, group_id: group.id).update_all(notification_level: level)

      PostAlerter.post_created(post)
      expect(
        user.notifications.where(notification_type: Notification.types[:watching_first_post]).count,
      ).to eq(1)
    end

    it "triggers :before_create_notifications_for_users" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      events = DiscourseEvent.track_events { PostAlerter.new.after_save_post(post, true) }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[user], post],
      )
    end

    it "sends a push notification when user has a push subscription" do
      setup_push_notification_subscription_for(user: user)

      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      events =
        DiscourseEvent.track_events(:push_notification) do
          PostAlerter.new.after_save_post(post, true)
        end

      expect(
        events.detect do |e|
          e[:params][0] == user &&
            e[:params][1][:notification_type] == Notification.types[:watching_first_post]
        end,
      ).to be_present
    end
  end

  context "with replies" do
    it "triggers :before_create_notifications_for_users" do
      _post = Fabricate(:post, user: user, topic: topic)
      reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)
      events = DiscourseEvent.track_events { PostAlerter.post_created(reply) }
      expect(events).to include(
        event_name: :before_create_notifications_for_users,
        params: [[user], reply],
      )
    end

    it "notifies about regular reply" do
      _post = Fabricate(:post, user: user, topic: topic)

      reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)
      PostAlerter.post_created(reply)

      expect(user.notifications.where(notification_type: Notification.types[:replied]).count).to eq(
        1,
      )
    end

    it "does not notify admins when suppress_secured_categories_from_admin is enabled" do
      SiteSetting.suppress_secured_categories_from_admin = true

      topic = Fabricate(:topic, category: private_category)
      post = Fabricate(:post, raw: "hello @#{admin.username} how are you today?", topic: topic)

      PostAlerter.post_created(post)

      expect(admin.notifications.count).to eq(0)
    end

    it "doesn't notify regular user about whispered reply" do
      _post = Fabricate(:post, user: user, topic: topic)

      whispered_reply =
        Fabricate(
          :post,
          user: admin,
          topic: topic,
          post_type: Post.types[:whisper],
          reply_to_post_number: 1,
        )
      PostAlerter.post_created(whispered_reply)

      expect(user.notifications.where(notification_type: Notification.types[:replied]).count).to eq(
        0,
      )
    end

    it "notifies staff user about whispered reply" do
      admin1 = Fabricate(:admin)
      admin2 = Fabricate(:admin)

      _post = Fabricate(:post, user: user, topic: topic)

      whispered_reply1 =
        Fabricate(
          :post,
          user: admin1,
          topic: topic,
          post_type: Post.types[:whisper],
          reply_to_post_number: 1,
        )
      whispered_reply2 =
        Fabricate(
          :post,
          user: admin2,
          topic: topic,
          post_type: Post.types[:whisper],
          reply_to_post_number: 2,
        )
      PostAlerter.post_created(whispered_reply1)
      PostAlerter.post_created(whispered_reply2)

      expect(
        admin1.notifications.where(notification_type: Notification.types[:replied]).count,
      ).to eq(1)

      TopicUser.change(
        admin1.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      # this should change nothing cause the moderator post has an action code
      # if we have an action code then we should never have notifications, this is rare but
      # assign whispers are like this
      whispered_reply3 =
        topic.add_moderator_post(
          admin2,
          "i am a reply",
          post_type: Post.types[:whisper],
          action_code: "moderator_thing",
        )
      PostAlerter.post_created(whispered_reply3)

      # if this whisper is not ignored like it should we would see a posted notification and no replied notifications
      notifications = admin1.notifications.where(topic_id: topic.id).to_a

      expect(notifications.first.notification_type).to eq(Notification.types[:replied])
      expect(notifications.length).to eq(1)
      expect(notifications.first.post_number).to eq(whispered_reply2.post_number)
    end

    it "sends email notifications only to users not on CC list of incoming email" do
      alice = Fabricate(:user, username: "alice", email: "alice@example.com")
      bob = Fabricate(:user, username: "bob", email: "bob@example.com")
      carol = Fabricate(:user, username: "carol", email: "carol@example.com", staged: true)
      dave = Fabricate(:user, username: "dave", email: "dave@example.com", staged: true)
      erin = Fabricate(:user, username: "erin", email: "erin@example.com")

      topic =
        Fabricate(
          :private_message_topic,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: alice),
            Fabricate.build(:topic_allowed_user, user: bob),
            Fabricate.build(:topic_allowed_user, user: carol),
            Fabricate.build(:topic_allowed_user, user: dave),
            Fabricate.build(:topic_allowed_user, user: erin),
          ],
        )
      _post = Fabricate(:post, user: alice, topic: topic)

      TopicUser.change(
        alice.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )
      TopicUser.change(
        bob.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )
      TopicUser.change(
        erin.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      email =
        Fabricate(
          :incoming_email,
          raw: <<~RAW,
                          Return-Path: <bob@example.com>
                          From: Bob <bob@example.com>
                          To: meta+1234@discoursemail.com, dave@example.com
                          CC: carol@example.com, erin@example.com
                          Subject: Hello world
                          Date: Fri, 15 Jan 2016 00:12:43 +0100
                          Message-ID: <12345@example.com>
                          Mime-Version: 1.0
                          Content-Type: text/plain; charset=UTF-8
                          Content-Transfer-Encoding: quoted-printable

                          This post was created by email.
                        RAW
          from_address: "bob@example.com",
          to_addresses: "meta+1234@discoursemail.com;dave@example.com",
          cc_addresses: "carol@example.com;erin@example.com",
        )
      reply =
        Fabricate(
          :post_via_email,
          user: bob,
          topic: topic,
          incoming_email: email,
          reply_to_post_number: 1,
        )

      NotificationEmailer.expects(:process_notification).with { |n| n.user_id == alice.id }.once
      NotificationEmailer.expects(:process_notification).with { |n| n.user_id == bob.id }.never
      NotificationEmailer.expects(:process_notification).with { |n| n.user_id == carol.id }.never
      NotificationEmailer.expects(:process_notification).with { |n| n.user_id == dave.id }.never
      NotificationEmailer.expects(:process_notification).with { |n| n.user_id == erin.id }.never

      PostAlerter.post_created(reply)

      expect(alice.notifications.count).to eq(1)
      expect(bob.notifications.count).to eq(0)
      expect(carol.notifications.count).to eq(1)
      expect(dave.notifications.count).to eq(1)
      expect(erin.notifications.count).to eq(1)
    end

    it "does not send email notifications to staged users when notification originates in mailinglist mirror category" do
      category = Fabricate(:mailinglist_mirror_category)
      topic = Fabricate(:topic, category: category)
      user = Fabricate(:staged)
      _post = Fabricate(:post, user: user, topic: topic)
      reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)

      NotificationEmailer.expects(:process_notification).never
      expect { PostAlerter.post_created(reply) }.not_to change(user.notifications, :count)

      category.mailinglist_mirror = false
      NotificationEmailer.expects(:process_notification).once
      expect { PostAlerter.post_created(reply) }.to change(user.notifications, :count).by(1)
    end

    it "creates a notification of type `replied` instead of `posted` for the topic author if they're watching the topic" do
      Jobs.run_immediately!

      u1 = Fabricate(:admin)
      u2 = Fabricate(:admin)

      topic = create_topic(user: u1)

      u1.notifications.destroy_all

      expect do create_post(topic: topic, user: u2) end.to change {
        u1.reload.notifications.count
      }.by(1)
      expect(
        u1.notifications.exists?(
          topic_id: topic.id,
          notification_type: Notification.types[:replied],
          post_number: 1,
          read: false,
        ),
      ).to eq(true)
    end

    it "it doesn't notify about small action posts when the topic author is watching the topic " do
      Jobs.run_immediately!

      u1 = Fabricate(:admin)
      u2 = Fabricate(:admin)

      topic = create_topic(user: u1)

      u1.notifications.destroy_all

      expect do topic.update_status("closed", true, u2, message: "hello world") end.not_to change {
        u1.reload.notifications.count
      }
    end
  end

  context "with category" do
    context "with watching" do
      it "triggers :before_create_notifications_for_users" do
        topic = Fabricate(:topic, category: category)
        post = Fabricate(:post, topic: topic)
        level = CategoryUser.notification_levels[:watching]
        CategoryUser.set_notification_level_for_category(user, level, category.id)
        events = DiscourseEvent.track_events { PostAlerter.post_created(post) }
        expect(events).to include(
          event_name: :before_create_notifications_for_users,
          params: [[user], post],
        )
      end

      it "notifies staff about whispered post" do
        topic = Fabricate(:topic, category: category)
        level = CategoryUser.notification_levels[:watching]
        CategoryUser.set_notification_level_for_category(admin, level, category.id)
        CategoryUser.set_notification_level_for_category(user, level, category.id)
        whispered_post =
          Fabricate(:post, user: Fabricate(:admin), topic: topic, post_type: Post.types[:whisper])
        expect { PostAlerter.post_created(whispered_post) }.to add_notification(
          admin,
          :watching_category_or_tag,
        )
        expect { PostAlerter.post_created(whispered_post) }.not_to add_notification(
          user,
          :watching_category_or_tag,
        )
      end

      it "notifies a staged user about a private post, but only if the user has access" do
        staged_member = Fabricate(:staged)
        staged_non_member = Fabricate(:staged)
        group_member = Fabricate(:user)

        group.add(group_member)
        group.add(staged_member)

        level = CategoryUser.notification_levels[:watching]
        CategoryUser.set_notification_level_for_category(group_member, level, private_category.id)
        CategoryUser.set_notification_level_for_category(staged_member, level, private_category.id)
        CategoryUser.set_notification_level_for_category(
          staged_non_member,
          level,
          private_category.id,
        )

        topic = Fabricate(:topic, category: private_category, user: group_member)
        post = Fabricate(:post, topic: topic)

        expect { PostAlerter.post_created(post) }.to add_notification(
          staged_member,
          :watching_category_or_tag,
        ).and not_add_notification(staged_non_member, :watching_category_or_tag)
      end

      it "does not update existing unread notification" do
        CategoryUser.set_notification_level_for_category(
          user,
          CategoryUser.notification_levels[:watching],
          category.id,
        )
        topic = Fabricate(:topic, category: category)

        post = Fabricate(:post, topic: topic)
        PostAlerter.post_created(post)
        notification = Notification.last
        expect(notification.topic_id).to eq(topic.id)
        expect(notification.post_number).to eq(1)

        post = Fabricate(:post, topic: topic)
        PostAlerter.post_created(post)
        notification = Notification.last
        expect(notification.topic_id).to eq(topic.id)
        expect(notification.post_number).to eq(1)
        notification_data = JSON.parse(notification.data)
        expect(notification_data["display_username"]).to eq(I18n.t("embed.replies", count: 2))
      end

      it "sends a push notification when user has a push subscription" do
        setup_push_notification_subscription_for(user: user)

        topic = Fabricate(:topic, category: category)
        post = Fabricate(:post, topic: topic)
        level = CategoryUser.notification_levels[:watching]
        CategoryUser.set_notification_level_for_category(user, level, category.id)
        events = DiscourseEvent.track_events(:push_notification) { PostAlerter.post_created(post) }

        expect(
          events.detect do |e|
            e[:params][0] == user &&
              e[:params][1][:notification_type] == Notification.types[:watching_category_or_tag]
          end,
        ).to be_present
      end
    end
  end

  context "with tags" do
    context "with watching" do
      it "triggers :before_create_notifications_for_users" do
        tag = Fabricate(:tag)
        topic = Fabricate(:topic, tags: [tag])
        post = Fabricate(:post, topic: topic)
        level = TagUser.notification_levels[:watching]
        TagUser.change(user.id, tag.id, level)
        events = DiscourseEvent.track_events { PostAlerter.post_created(post) }
        expect(events).to include(
          event_name: :before_create_notifications_for_users,
          params: [[user], post],
        )
      end

      it "does not update existing unread notification" do
        tag = Fabricate(:tag)
        TagUser.change(user.id, tag.id, TagUser.notification_levels[:watching])
        topic = Fabricate(:topic, tags: [tag])

        post = Fabricate(:post, topic: topic)
        PostAlerter.post_created(post)
        notification = Notification.last
        expect(notification.topic_id).to eq(topic.id)
        expect(notification.post_number).to eq(1)

        post = Fabricate(:post, topic: topic)
        PostAlerter.post_created(post)
        notification = Notification.last
        expect(notification.topic_id).to eq(topic.id)
        expect(notification.post_number).to eq(1)
        notification_data = JSON.parse(notification.data)
        expect(notification_data["display_username"]).to eq(I18n.t("embed.replies", count: 2))
      end

      it "does not add notification if user does not belong to tag group with permissions" do
        tag = Fabricate(:tag)
        topic = Fabricate(:topic, tags: [tag])
        post = Fabricate(:post, topic: topic)

        tag_group = TagGroup.new(name: "Only visible to group", tag_names: [tag.name])
        tag_group.permissions = [[group.id, TagGroupPermission.permission_types[:full]]]
        tag_group.save!

        TagUser.change(user.id, tag.id, TagUser.notification_levels[:watching])

        expect { PostAlerter.post_created(post) }.not_to change { Notification.count }
      end

      it "adds notification if user belongs to tag group with permissions" do
        tag = Fabricate(:tag)
        topic = Fabricate(:topic, tags: [tag])
        post = Fabricate(:post, topic: topic)
        tag_group = Fabricate(:tag_group, tags: [tag])
        Fabricate(:group_user, group: group, user: user)
        Fabricate(:tag_group_permission, tag_group: tag_group, group: group)

        TagUser.change(user.id, tag.id, TagUser.notification_levels[:watching])

        expect { PostAlerter.post_created(post) }.to change { Notification.count }.by(1)
      end
    end

    context "with category and tags" do
      fab!(:muted_category) do
        Fabricate(:category).tap do |category|
          CategoryUser.set_notification_level_for_category(
            user,
            CategoryUser.notification_levels[:muted],
            category.id,
          )
        end
      end
      fab!(:muted_tag) do
        Fabricate(:tag).tap do |tag|
          TagUser.create!(
            user: user,
            tag: tag,
            notification_level: TagUser.notification_levels[:muted],
          )
        end
      end
      fab!(:watched_tag) do
        Fabricate(:tag).tap do |tag|
          TagUser.create!(
            user: user,
            tag: tag,
            notification_level: TagUser.notification_levels[:watching],
          )
        end
      end
      fab!(:topic_with_muted_tag_and_watched_category) do
        Fabricate(:topic, category: category, tags: [muted_tag])
      end
      fab!(:topic_with_muted_category_and_watched_tag) do
        Fabricate(:topic, category: muted_category, tags: [watched_tag])
      end
      fab!(:directly_watched_topic) do
        Fabricate(:topic, category: muted_category, tags: [muted_tag])
      end
      fab!(:topic_user) do
        Fabricate(
          :topic_user,
          topic: directly_watched_topic,
          user: user,
          notification_level: TopicUser.notification_levels[:watching],
        )
      end
      fab!(:topic_with_watched_category) { Fabricate(:topic, category: category) }
      fab!(:post) { Fabricate(:post, topic: topic_with_muted_tag_and_watched_category) }
      fab!(:post_2) { Fabricate(:post, topic: topic_with_muted_category_and_watched_tag) }
      fab!(:post_3) { Fabricate(:post, topic: topic_with_watched_category) }
      fab!(:post_4) { Fabricate(:post, topic: directly_watched_topic) }

      before do
        CategoryUser.set_notification_level_for_category(
          user,
          CategoryUser.notification_levels[:watching],
          category.id,
        )
      end

      it "adds notification when watched_precedence_over_muted setting is true" do
        SiteSetting.watched_precedence_over_muted = true
        expect {
          PostAlerter.post_created(topic_with_muted_tag_and_watched_category.posts.first)
        }.to change { Notification.count }.by(1)
        expect {
          PostAlerter.post_created(topic_with_muted_category_and_watched_tag.posts.first)
        }.to change { Notification.count }.by(1)
        expect { PostAlerter.post_created(directly_watched_topic.posts.first) }.to change {
          Notification.count
        }.by(1)
      end

      it "respects user option even if watched_precedence_over_muted site setting is true" do
        SiteSetting.watched_precedence_over_muted = true
        user.user_option.update!(watched_precedence_over_muted: false)
        expect {
          PostAlerter.post_created(topic_with_muted_tag_and_watched_category.posts.first)
        }.not_to change { Notification.count }
        expect {
          PostAlerter.post_created(topic_with_muted_category_and_watched_tag.posts.first)
        }.not_to change { Notification.count }
        expect { PostAlerter.post_created(directly_watched_topic.posts.first) }.to change {
          Notification.count
        }.by(1)
      end

      it "does not add notification when watched_precedence_over_muted setting is false" do
        SiteSetting.watched_precedence_over_muted = false
        expect {
          PostAlerter.post_created(topic_with_muted_tag_and_watched_category.posts.first)
        }.not_to change { Notification.count }
        expect {
          PostAlerter.post_created(topic_with_muted_category_and_watched_tag.posts.first)
        }.not_to change { Notification.count }
        expect { PostAlerter.post_created(topic_with_watched_category.posts.first) }.to change {
          Notification.count
        }.by(1)
        expect { PostAlerter.post_created(directly_watched_topic.posts.first) }.to change {
          Notification.count
        }.by(1)
      end

      it "respects user option even if watched_precedence_over_muted site setting is false" do
        SiteSetting.watched_precedence_over_muted = false
        user.user_option.update!(watched_precedence_over_muted: true)
        expect {
          PostAlerter.post_created(topic_with_muted_tag_and_watched_category.posts.first)
        }.to change { Notification.count }.by(1)
        expect {
          PostAlerter.post_created(topic_with_muted_category_and_watched_tag.posts.first)
        }.to change { Notification.count }.by(1)
        expect { PostAlerter.post_created(directly_watched_topic.posts.first) }.to change {
          Notification.count
        }.by(1)
      end
    end

    context "with on change" do
      fab!(:user)
      fab!(:other_tag) { Fabricate(:tag) }
      fab!(:watched_tag) { Fabricate(:tag) }

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        Jobs.run_immediately!
        TagUser.change(user.id, watched_tag.id, TagUser.notification_levels[:watching_first_post])
        TopicUser.change(
          Fabricate(:user).id,
          post.topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
      end

      it "triggers a notification" do
        expect(
          user
            .notifications
            .where(notification_type: Notification.types[:watching_first_post])
            .count,
        ).to eq(0)

        expect {
          PostRevisor.new(post).revise!(
            Fabricate(:user, refresh_auto_groups: true),
            tags: [other_tag.name, watched_tag.name],
          )
        }.to change { Notification.where(user_id: user.id).count }.by(1)
        expect(
          user
            .notifications
            .where(notification_type: Notification.types[:watching_first_post])
            .count,
        ).to eq(1)

        expect {
          PostRevisor.new(post).revise!(
            Fabricate(:user, refresh_auto_groups: true),
            tags: [watched_tag.name, other_tag.name],
          )
        }.not_to change { Notification.count }
        expect(
          user
            .notifications
            .where(notification_type: Notification.types[:watching_first_post])
            .count,
        ).to eq(1)
      end

      it "doesn't trigger a notification if topic is unlisted" do
        post.topic.update_column(:visible, false)

        expect(
          user
            .notifications
            .where(notification_type: Notification.types[:watching_first_post])
            .count,
        ).to eq(0)

        PostRevisor.new(post).revise!(Fabricate(:user), tags: [other_tag.name, watched_tag.name])
        expect(
          user
            .notifications
            .where(notification_type: Notification.types[:watching_first_post])
            .count,
        ).to eq(0)
      end
    end

    context "with private message" do
      fab!(:post) { Fabricate(:private_message_post) }
      fab!(:other_tag) { Fabricate(:tag) }
      fab!(:other_tag2) { Fabricate(:tag) }
      fab!(:other_tag3) { Fabricate(:tag) }
      fab!(:user)
      fab!(:staged)

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.pm_tags_allowed_for_groups = "1|2|3"
        Jobs.run_immediately!
        TopicUser.change(
          user.id,
          post.topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        TopicUser.change(
          staged.id,
          post.topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        TopicUser.change(
          admin.id,
          post.topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        TagUser.change(staged.id, other_tag.id, TagUser.notification_levels[:watching])
        TagUser.change(admin.id, other_tag3.id, TagUser.notification_levels[:watching])
        post.topic.allowed_users << user
        post.topic.allowed_users << staged
      end

      it "only notifies staff watching added tag" do
        expect(
          PostRevisor.new(post).revise!(
            Fabricate(:admin, refresh_auto_groups: true),
            tags: [other_tag.name],
          ),
        ).to be true
        expect(Notification.where(user_id: staged.id).count).to eq(0)
        expect(
          PostRevisor.new(post).revise!(
            Fabricate(:admin, refresh_auto_groups: true),
            tags: [other_tag2.name],
          ),
        ).to be true
        expect(Notification.where(user_id: admin.id).count).to eq(0)
        expect(
          PostRevisor.new(post).revise!(
            Fabricate(:admin, refresh_auto_groups: true),
            tags: [other_tag3.name],
          ),
        ).to be true
        expect(Notification.where(user_id: admin.id).count).to eq(1)
      end
    end

    context "with tag groups" do
      fab!(:tag)
      fab!(:user)
      fab!(:topic) { Fabricate(:topic, tags: [tag]) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      shared_examples "tag user with notification level" do |notification_level, notification_type|
        it "notifies a user who is watching a tag that does not belong to a tag group" do
          TagUser.change(user.id, tag.id, TagUser.notification_levels[notification_level])
          PostAlerter.post_created(post)
          expect(
            user
              .notifications
              .where(notification_type: Notification.types[notification_type])
              .count,
          ).to eq(1)
        end

        it "does not notify a user watching a tag with tag group permissions that he does not belong to" do
          tag_group = Fabricate(:tag_group, tags: [tag], permissions: { group.name => 1 })

          TagUser.change(user.id, tag.id, TagUser.notification_levels[notification_level])

          PostAlerter.post_created(post)

          expect(
            user
              .notifications
              .where(notification_type: Notification.types[notification_type])
              .count,
          ).to eq(0)
        end

        it "notifies a user watching a tag with tag group permissions that he belongs to" do
          Fabricate(:group_user, group: group, user: user)

          TagUser.change(user.id, tag.id, TagUser.notification_levels[notification_level])

          PostAlerter.post_created(post)

          expect(
            user
              .notifications
              .where(notification_type: Notification.types[notification_type])
              .count,
          ).to eq(1)
        end

        it "notifies a staff watching a tag with tag group permissions that he does not belong to" do
          tag_group = Fabricate(:tag_group, tags: [tag])
          Fabricate(:tag_group_permission, tag_group: tag_group, group: group)
          staff_group = Group.find(Group::AUTO_GROUPS[:staff])
          Fabricate(:group_user, group: staff_group, user: user)

          TagUser.change(user.id, tag.id, TagUser.notification_levels[notification_level])

          PostAlerter.post_created(post)

          expect(
            user
              .notifications
              .where(notification_type: Notification.types[notification_type])
              .count,
          ).to eq(1)
        end
      end

      context "with :watching notification level" do
        include_examples "tag user with notification level", :watching, :watching_category_or_tag
      end

      context "with :watching_first_post notification level" do
        include_examples "tag user with notification level",
                         :watching_first_post,
                         :watching_first_post
      end
    end
  end

  describe "#extract_linked_users" do
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:post2) { Fabricate(:post) }

    describe "when linked post has been deleted" do
      let(:topic_link) do
        TopicLink.create!(
          url: "/t/#{topic.id}",
          topic_id: topic.id,
          link_topic_id: post2.topic.id,
          link_post_id: nil,
          post_id: post.id,
          user: user,
          domain: "test.com",
        )
      end

      it "should use the first post of the topic" do
        topic_link
        expect(PostAlerter.new.extract_linked_users(post.reload)).to eq([post2.user])
      end
    end
  end

  describe "#notify_post_users" do
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:last_editor) { Fabricate(:user) }
    fab!(:tag)
    fab!(:category)

    it "creates single edit notification when post is modified" do
      TopicUser.create!(
        user_id: user.id,
        topic_id: topic.id,
        notification_level: TopicUser.notification_levels[:watching],
        last_read_post_number: post.post_number,
      )

      PostRevisor.new(post).revise!(last_editor, tags: [tag.name])
      PostAlerter.new.notify_post_users(post, [])
      expect(Notification.count).to eq(1)
      expect(Notification.last.notification_type).to eq(Notification.types[:edited])
      expect(JSON.parse(Notification.last.data)["display_username"]).to eq(last_editor.username)

      PostAlerter.new.notify_post_users(post, [])
      expect(Notification.count).to eq(1)
    end

    it "creates posted notification when Sidekiq is slow" do
      CategoryUser.set_notification_level_for_category(
        user,
        CategoryUser.notification_levels[:watching],
        category.id,
      )

      post =
        PostCreator.create!(
          Fabricate(:user, refresh_auto_groups: true),
          title: "one of my first topics",
          raw: "one of my first posts",
          category: category.id,
        )

      TopicUser.change(user, post.topic_id, last_read_post_number: post.post_number)

      # Manually run job after the user read the topic to simulate a slow
      # Sidekiq.
      job_args = Jobs::PostAlert.jobs[0]["args"][0]
      expect { Jobs::PostAlert.new.execute(job_args.with_indifferent_access) }.to change {
        Notification.count
      }.by(1)

      expect(Notification.last.notification_type).to eq(Notification.types[:posted])
    end
  end

  context "with SMTP (group_smtp_email)" do
    before do
      SiteSetting.enable_smtp = true
      SiteSetting.email_in = true
      Jobs.run_immediately!
    end

    fab!(:group) do
      Fabricate(
        :group,
        smtp_server: "smtp.gmail.com",
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        imap_server: "imap.gmail.com",
        imap_port: 993,
        imap_ssl: true,
        email_username: "discourse@example.com",
        email_password: "password",
        smtp_enabled: true,
        imap_enabled: true,
      )
    end

    def create_post_with_incoming
      raw_mail = <<~EMAIL
      From: Foo <foo@discourse.org>
      To: discourse@example.com
      Cc: bar@discourse.org, jim@othersite.com
      Subject: Full email group username flow
      Date: Fri, 15 Jan 2021 00:12:43 +0100
      Message-ID: <u4w8c9r4y984yh98r3h69873@example.com.mail>
      Mime-Version: 1.0
      Content-Type: text/plain
      Content-Transfer-Encoding: 7bit

      This is the first email.
      EMAIL

      Email::Receiver.new(raw_mail, {}).process!
    end

    it "does not error if SMTP is enabled and the topic has no incoming email or allowed groups" do
      expect { PostAlerter.new.after_save_post(post, true) }.not_to raise_error
    end

    it "does not error if SMTP is enabled and the topic has no incoming email but does have an allowed group" do
      TopicAllowedGroup.create(topic: private_message_topic, group: group)
      expect { PostAlerter.new.after_save_post(post, true) }.not_to raise_error
    end

    it "does not error if SMTP is enabled and the topic has no incoming email but has multiple allowed groups" do
      TopicAllowedGroup.create(topic: private_message_topic, group: group)
      TopicAllowedGroup.create(topic: private_message_topic, group: Fabricate(:group))
      expect { PostAlerter.new.after_save_post(post, true) }.not_to raise_error
    end

    it "sends a group smtp email because SMTP is enabled for the site and the group" do
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic)
      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
      email = ActionMailer::Base.deliveries.last
      expect(email.from).to include(group.email_username)
      expect(email.to).to contain_exactly(
        topic.reload.topic_allowed_users.order(:created_at).first.user.email,
      )
      expect(email.cc).to match_array(%w[bar@discourse.org jim@othersite.com])
      expect(email.subject).to eq("Re: #{topic.title}")
    end

    it "sends a group smtp email when the original group has had SMTP disabled and there is an additional topic allowed group" do
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      other_allowed_group = Fabricate(:smtp_group)
      TopicAllowedGroup.create(group: other_allowed_group, topic: topic)
      post = Fabricate(:post, topic: topic)
      group.update!(smtp_enabled: false)

      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.from).to include(other_allowed_group.email_username)
      expect(email.to).to contain_exactly(
        topic.reload.topic_allowed_users.order(:created_at).first.user.email,
      )
      expect(email.cc).to match_array(%w[bar@discourse.org jim@othersite.com])
      expect(email.subject).to eq("Re: #{topic.title}")
    end

    it "does not send a group smtp email if smtp is not enabled for the group" do
      group.update!(smtp_enabled: false)
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic)
      expect { PostAlerter.new.after_save_post(post, true) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "does not send a group smtp email if SiteSetting.enable_smtp is false" do
      SiteSetting.enable_smtp = false
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic)
      expect { PostAlerter.new.after_save_post(post, true) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "does not send group smtp emails for a whisper" do
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      expect { PostAlerter.new.after_save_post(post, true) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "sends the group smtp email job with a delay of personal_email_time_window_seconds" do
      freeze_time
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic)
      PostAlerter.new.after_save_post(post, true)
      job_enqueued?(
        job: :group_smtp_email,
        args: {
          group_id: group.id,
          post_id: post.id,
          email: topic.reload.topic_allowed_users.order(:created_at).first.user.email,
          cc_emails: %w[bar@discourse.org jim@othersite.com],
        },
        at: Time.zone.now + SiteSetting.personal_email_time_window_seconds.seconds,
      )
    end

    it "does not send a group smtp email for anyone if the reply post originates from an incoming email that is auto generated" do
      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic)
      Fabricate(:incoming_email, post: post, topic: topic, is_auto_generated: true)
      expect_not_enqueued_with(job: :group_smtp_email) do
        expect { PostAlerter.new.after_save_post(post, true) }.not_to change {
          ActionMailer::Base.deliveries.size
        }
      end
    end

    it "skips sending a notification email to the group and all other email addresses that are _not_ members of the group,
    sends a group_smtp_email instead" do
      NotificationEmailer.enable

      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic

      group_user1 = Fabricate(:group_user, group: group)
      group_user2 = Fabricate(:group_user, group: group)
      TopicUser.create(
        user: group_user1.user,
        notification_level: TopicUser.notification_levels[:watching],
        topic: topic,
      )
      post = Fabricate(:post, topic: topic.reload)

      # Sends an email for:
      #
      # 1. the group user that is watching the post (but does not send this email with group SMTO)
      # 2. the group smtp email to notify all topic_users not in the group
      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(2).and change { Notification.count }.by(2)

      # The group smtp email
      email = ActionMailer::Base.deliveries.first
      expect(email.from).to eq([group.email_username])
      expect(email.to).to contain_exactly("foo@discourse.org")
      expect(email.cc).to match_array(%w[bar@discourse.org jim@othersite.com])
      expect(email.subject).to eq("Re: #{topic.title}")

      # The watching group user notification email
      email = ActionMailer::Base.deliveries.last
      expect(email.from).to eq([SiteSetting.notification_email])
      expect(email.to).to contain_exactly(group_user1.user.email)
      expect(email.cc).to eq(nil)
      expect(email.subject).to eq("[Discourse] [PM] #{topic.title}")
    end

    it "skips sending a notification email to the cc address that was added on the same post with an incoming email" do
      NotificationEmailer.enable

      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic

      post = Fabricate(:post, topic: topic.reload)
      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1).and change { Notification.count }.by(1)
      email = ActionMailer::Base.deliveries.last

      # the reply post from someone who was emailed
      reply_raw_mail = <<~EMAIL
      From: Bar <bar@discourse.org>
      To: discourse@example.com
      Cc: someothernewcc@baz.com, finalnewcc@doom.com
      Subject: #{email.subject}
      Date: Fri, 16 Jan 2021 00:12:43 +0100
      Message-ID: <sdugj3o4iyu4832x3487@discourse.org.mail>
      In-Reply-To: #{email.message_id}
      Mime-Version: 1.0
      Content-Type: text/plain
      Content-Transfer-Encoding: 7bit

      Hey here is my reply!
      EMAIL

      reply_post_from_email = nil
      expect {
        reply_post_from_email = Email::Receiver.new(reply_raw_mail, {}).process!
      }.to change {
        User.count # the two new cc addresses have users created
      }.by(2).and change {
              TopicAllowedUser.where(topic: topic).count # and they are added as topic allowed users
            }.by(2).and change {
                    # but they are not sent emails because they were cc'd on an email, only jim@othersite.com
                    # is emailed because he is a topic allowed user cc'd on the _original_ email and he is not
                    # the one creating the post, and foo@discourse.org, who is the OP of the topic
                    ActionMailer::Base.deliveries.size
                  }.by(1).and change {
                          Notification.count # and they are still sent their normal discourse notification
                        }.by(2)

      email = ActionMailer::Base.deliveries.last

      expect(email.to).to eq(["foo@discourse.org"])
      expect(email.cc).to eq(["jim@othersite.com"])
      expect(email.from).to eq([group.email_username])
      expect(email.subject).to eq("Re: #{topic.title}")
    end

    it "handles the OP of the topic replying by email and sends a group email to the other topic allowed users successfully" do
      NotificationEmailer.enable

      incoming_email_post = create_post_with_incoming
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic.reload)
      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1).and change { Notification.count }.by(1)
      email = ActionMailer::Base.deliveries.last

      # the reply post from someone who was emailed
      reply_raw_mail = <<~EMAIL
      From: Foo <foo@discourse.org>
      To: discourse@example.com
      Cc: someothernewcc@baz.com, finalnewcc@doom.com
      Subject: #{email.subject}
      Date: Fri, 16 Jan 2021 00:12:43 +0100
      Message-ID: <sgk094238uc0348c334483@discourse.org.mail>
      In-Reply-To: #{email.message_id}
      Mime-Version: 1.0
      Content-Type: text/plain
      Content-Transfer-Encoding: 7bit

      I am ~~Commander Shepherd~~ the OP and I approve of this message.
      EMAIL

      reply_post_from_email = nil
      expect {
        reply_post_from_email = Email::Receiver.new(reply_raw_mail, {}).process!
      }.to change {
        User.count # the two new cc addresses have users created
      }.by(2).and change {
              TopicAllowedUser.where(topic: topic).count # and they are added as topic allowed users
            }.by(2).and change {
                    # but they are not sent emails because they were cc'd on an email, only jim@othersite.com
                    # is emailed because he is a topic allowed user cc'd on the _original_ email and he is not
                    # the one creating the post
                    ActionMailer::Base.deliveries.size
                  }.by(1).and change {
                          Notification.count # and they are still sent their normal discourse notification
                        }.by(2)

      email = ActionMailer::Base.deliveries.last

      expect(email.to).to eq(["bar@discourse.org"])
      expect(email.cc).to eq(["jim@othersite.com"])
      expect(email.from).to eq([group.email_username])
      expect(email.subject).to eq("Re: #{topic.title}")
    end

    it "handles the OP of the topic replying by email and cc'ing new people, and does not send a group SMTP email to those newly cc'd users" do
      NotificationEmailer.enable

      # this is a special case where we are not CC'ing on the original email,
      # only on the follow up email
      raw_mail = <<~EMAIL
      From: Foo <foo@discourse.org>
      To: discourse@example.com
      Subject: Full email group username flow
      Date: Fri, 14 Jan 2021 00:12:43 +0100
      Message-ID: <f4832ujfc3498u398i3@example.com.mail>
      Mime-Version: 1.0
      Content-Type: text/plain
      Content-Transfer-Encoding: 7bit

      This is the first email.
      EMAIL

      incoming_email_post = Email::Receiver.new(raw_mail, {}).process!
      topic = incoming_email_post.topic
      post = Fabricate(:post, topic: topic.reload)
      expect { PostAlerter.new.after_save_post(post, true) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1).and change { Notification.count }.by(1)
      email = ActionMailer::Base.deliveries.last

      # the reply post from the OP, cc'ing new people in
      reply_raw_mail = <<~EMAIL
      From: Foo <foo@discourse.org>
      To: discourse@example.com
      Cc: someothernewcc@baz.com, finalnewcc@doom.com
      Subject: #{email.subject}
      Date: Fri, 16 Jan 2021 00:12:43 +0100
      Message-ID: <3849cu9843yncr9834yr9348x934@discourse.org.mail>
      In-Reply-To: #{email.message_id}
      Mime-Version: 1.0
      Content-Type: text/plain
      Content-Transfer-Encoding: 7bit

      I am inviting my mates to this email party.
      EMAIL

      reply_post_from_email = nil
      expect {
        reply_post_from_email = Email::Receiver.new(reply_raw_mail, {}).process!
      }.to change {
        User.count # the two new cc addresses have users created
      }.by(2).and change {
              TopicAllowedUser.where(topic: topic).count # and they are added as topic allowed users
            }.by(2).and not_change {
                    # but they are not sent emails because they were cc'd on an email.
                    # no group smtp message is sent because the OP is not sent an email,
                    # they made this post.
                    ActionMailer::Base.deliveries.size
                  }.and change {
                          Notification.count # and they are still sent their normal discourse notification
                        }.by(2)

      last_email = ActionMailer::Base.deliveries.last
      expect(email).to eq(last_email)
    end
  end

  describe "storing custom data" do
    let(:custom_data) { "custom_string" }

    it "stores custom data inside a notification" do
      PostAlerter.new.create_notification(
        admin,
        Notification.types[:liked],
        post,
        custom_data: {
          custom_key: custom_data,
        },
      )

      liked_notification = Notification.where(notification_type: Notification.types[:liked]).last

      expect(liked_notification.data_hash[:custom_key]).to eq(custom_data)
    end
  end

  it "does not create notifications for PMs if not invited" do
    SiteSetting.pm_tags_allowed_for_groups = "#{Group::AUTO_GROUPS[:everyone]}"
    watching_first_post_tag = Fabricate(:tag)
    TagUser.change(
      admin.id,
      watching_first_post_tag.id,
      TagUser.notification_levels[:watching_first_post],
    )
    watching_tag = Fabricate(:tag)
    TagUser.change(admin.id, watching_tag.id, TagUser.notification_levels[:watching])

    post =
      create_post(
        tags: [watching_first_post_tag.name, watching_tag.name],
        archetype: Archetype.private_message,
        target_usernames: "#{evil_trout.username}",
      )
    expect { PostAlerter.new.after_save_post(post, true) }.to change { Notification.count }.by(1)

    notification = Notification.last
    expect(notification.user).to eq(evil_trout)
    expect(notification.notification_type).to eq(Notification.types[:private_message])
    expect(notification.topic).to eq(post.topic)
    expect(notification.post_number).to eq(1)
  end

  it "does not create multiple notifications for same post" do
    category = Fabricate(:category)
    CategoryUser.set_notification_level_for_category(
      user,
      NotificationLevels.all[:tracking],
      category.id,
    )
    watching_first_post_tag = Fabricate(:tag)
    TagUser.change(
      user.id,
      watching_first_post_tag.id,
      TagUser.notification_levels[:watching_first_post],
    )
    watching_tag = Fabricate(:tag)
    TagUser.change(user.id, watching_tag.id, TagUser.notification_levels[:watching])

    post = create_post(category: category, tags: [watching_first_post_tag.name, watching_tag.name])
    expect { PostAlerter.new.after_save_post(post, true) }.to change { Notification.count }.by(1)

    notification = Notification.last
    expect(notification.user).to eq(user)
    expect(notification.notification_type).to eq(Notification.types[:watching_category_or_tag])
    expect(notification.topic).to eq(post.topic)
    expect(notification.post_number).to eq(1)
  end

  it "triggers all discourse events" do
    expected_events = %i[
      post_alerter_before_mentions
      post_alerter_before_replies
      post_alerter_before_quotes
      post_alerter_before_linked
      post_alerter_before_post
      post_alerter_before_first_post
      post_alerter_after_save_post
    ]

    events = DiscourseEvent.track_events { PostAlerter.new.after_save_post(post, true) }

    # Expect all the notification events are called
    # There are some other events triggered from outside after_save_post
    expect(events.map { |e| e[:event_name] }).to include(*expected_events)

    # Expect each notification event is called with the right parameters
    events.each do |event|
      if expected_events.include?(event[:event_name])
        expect(event[:params]).to eq([post, true, [post.user]])
      end
    end
  end
end
