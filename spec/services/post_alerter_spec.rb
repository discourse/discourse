require 'rails_helper'

describe PostAlerter do

  let!(:evil_trout) { Fabricate(:evil_trout) }
  let(:user) { Fabricate(:user) }

  def create_post_with_alerts(args = {})
    post = Fabricate(:post, args)
    PostAlerter.post_created(post)
  end

  context "private message" do
    it "notifies for pms correctly" do
      pm = Fabricate(:topic, archetype: 'private_message', category_id: nil)
      op = Fabricate(:post, user_id: pm.user_id)
      pm.allowed_users << pm.user
      PostAlerter.post_created(op)
      reply = Fabricate(:post, user_id: pm.user_id, topic_id: pm.id, reply_to_post_number: 1)
      PostAlerter.post_created(reply)

      reply2 = Fabricate(:post, topic_id: pm.id, reply_to_post_number: 1)
      PostAlerter.post_created(reply2)

      # we get a green notification for a reply
      expect(Notification.where(user_id: pm.user_id).pluck(:notification_type).first).to eq(Notification.types[:private_message])

      TopicUser.change(pm.user_id, pm.id, notification_level: TopicUser.notification_levels[:tracking])

      Notification.destroy_all

      reply3 = Fabricate(:post, topic_id: pm.id)
      PostAlerter.post_created(reply3)

      # no notification cause we are tracking
      expect(Notification.where(user_id: pm.user_id).count).to eq(0)

      Notification.destroy_all

      reply4 = Fabricate(:post, topic_id: pm.id, reply_to_post_number: 1)
      PostAlerter.post_created(reply4)

      # yes notification cause we were replied to
      expect(Notification.where(user_id: pm.user_id).count).to eq(1)

    end

    it "triggers :before_create_notifications_for_users" do
      pm = Fabricate(:topic, archetype: 'private_message', category_id: nil)
      op = Fabricate(:post, user_id: pm.user_id, topic: pm)
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)
      group = Fabricate(:group, users: [user2])
      pm.allowed_users << user1
      pm.allowed_groups << group
      events = DiscourseEvent.track_events do
        PostAlerter.post_created(op)
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user1], op])
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user2], op])
    end
  end

  context "unread" do
    it "does not return whispers as unread posts" do
      op = Fabricate(:post)
      _whisper = Fabricate(:post, raw: 'this is a whisper post',
                                  user: Fabricate(:admin),
                                  topic: op.topic,
                                  reply_to_post_number: op.post_number,
                                  post_type: Post.types[:whisper])

      expect(PostAlerter.new.first_unread_post(op.user, op.topic)).to be_blank
    end
  end

  context 'edits' do
    it 'notifies correctly on edits' do
      PostActionNotifier.enable

      post = Fabricate(:post, raw: 'I love waffles')

      admin = Fabricate(:admin)
      post.revise(admin, raw: 'I made a revision')

      # skip this notification cause we already notified on a similar edit
      freeze_time 2.hours.from_now
      post.revise(admin, raw: 'I made another revision')

      post.revise(Fabricate(:admin), raw: 'I made a revision')

      freeze_time 2.hours.from_now
      post.revise(admin, raw: 'I made another revision')

      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count).to eq(3)
    end
  end

  context 'likes' do

    it 'notifies on likes after an undo' do
      PostActionNotifier.enable

      post = Fabricate(:post, raw: 'I love waffles')

      PostAction.act(evil_trout, post, PostActionType.types[:like])
      PostAction.remove_act(evil_trout, post, PostActionType.types[:like])
      PostAction.act(evil_trout, post, PostActionType.types[:like])

      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count).to eq(1)
    end

    it 'notifies on does not notify when never is selected' do
      PostActionNotifier.enable

      post = Fabricate(:post, raw: 'I love waffles')

      post.user.user_option.update_columns(like_notification_frequency:
                                           UserOption.like_notification_frequency_type[:never])

      PostAction.act(evil_trout, post, PostActionType.types[:like])

      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count).to eq(0)
    end

    it 'notifies on likes correctly' do
      PostActionNotifier.enable

      post = Fabricate(:post, raw: 'I love waffles')

      PostAction.act(evil_trout, post, PostActionType.types[:like])
      admin = Fabricate(:admin)
      PostAction.act(admin, post, PostActionType.types[:like])

      # one like
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(1)

      post.user.user_option.update_columns(
        like_notification_frequency: UserOption.like_notification_frequency_type[:always]
      )

      admin2 = Fabricate(:admin)

      # Travel 1 hour in time to test that order post_actions by `created_at`
      freeze_time 1.hour.from_now
      PostAction.act(admin2, post, PostActionType.types[:like])

      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(1)

      # adds info to the notification
      notification = Notification.find_by(
        post_number: 1,
        topic_id: post.topic_id
      )

      expect(notification.data_hash["count"].to_i).to eq(2)
      expect(notification.data_hash["username2"]).to eq(evil_trout.username)

      # this is a tricky thing ... removing a like should fix up the notifications
      PostAction.remove_act(evil_trout, post, PostActionType.types[:like])

      # rebuilds the missing notification
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(1)

      notification = Notification.find_by(
        post_number: 1,
        topic_id: post.topic_id
      )

      expect(notification.data_hash["count"]).to eq(2)
      expect(notification.data_hash["username"]).to eq(admin2.username)
      expect(notification.data_hash["username2"]).to eq(admin.username)

      post.user.user_option.update_columns(like_notification_frequency:
                                           UserOption.like_notification_frequency_type[:first_time_and_daily])

      # this gets skipped
      admin3 = Fabricate(:admin)
      PostAction.act(admin3, post, PostActionType.types[:like])

      freeze_time 2.days.from_now

      admin4 = Fabricate(:admin)
      PostAction.act(admin4, post, PostActionType.types[:like])

      # first happend within the same day, no need to notify
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count).to eq(2)

    end
  end

  context 'quotes' do

    it 'does not notify for muted users' do
      post = Fabricate(:post, raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      MutedUser.create!(user_id: evil_trout.id, muted_user_id: post.user_id)

      expect {
        PostAlerter.post_created(post)
      }.to change(evil_trout.notifications, :count).by(0)
    end

    it 'notifies a user by username' do
      expect {
        create_post_with_alerts(raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      }.to change(evil_trout.notifications, :count).by(1)
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
        Fabricate(:post, topic: topic, user: topic.user, raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]')
      }.not_to change(topic.user.notifications, :count)
    end

    it "triggers :before_create_notifications_for_users" do
      post = Fabricate(:post, raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      events = DiscourseEvent.track_events do
        PostAlerter.post_created(post)
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[evil_trout], post])
    end
  end

  context 'linked' do
    let(:post1) { create_post }
    let(:user) { post1.user }
    let(:linking_post) { create_post(raw: "my magic topic\n##{Discourse.base_url}#{post1.url}") }

    it "will notify correctly on linking" do
      linking_post

      expect(user.notifications.count).to eq(1)

      topic = Fabricate(:topic)

      watcher = Fabricate(:user)
      TopicUser.create!(user_id: watcher.id, topic_id: topic.id, notification_level: TopicUser.notification_levels[:watching])

      create_post(topic_id: topic.id, user: user, raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      user.reload
      expect(user.notifications.where(notification_type: Notification.types[:linked]).count).to eq(1)

      expect(watcher.notifications.count).to eq(1)

      # don't notify on reflection
      post1.reload
      expect(PostAlerter.new.extract_linked_users(post1).length).to eq(0)
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events do
        linking_post
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user], linking_post])
    end
  end

  context '@group mentions' do

    let(:group) { Fabricate(:group, name: 'group', mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
    let(:post) { create_post_with_alerts(raw: "Hello @group how are you?") }
    before { group.add(evil_trout) }

    it 'notifies users correctly' do
      expect {
        post
      }.to change(evil_trout.notifications, :count).by(1)

      expect(GroupMention.count).to eq(1)

      Fabricate(:group, name: 'group-alt', mentionable_level: Group::ALIAS_LEVELS[:everyone])

      expect {
        create_post_with_alerts(raw: "Hello, @group-alt should not trigger a notification?")
      }.to change(evil_trout.notifications, :count).by(0)

      expect(GroupMention.count).to eq(2)

      group.update_columns(mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins])
      expect {
        create_post_with_alerts(raw: "Hello @group you are not mentionable")
      }.to change(evil_trout.notifications, :count).by(0)

      expect(GroupMention.count).to eq(3)
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events do
        post
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[evil_trout], post])
    end
  end

  context '@mentions' do

    let(:mention_post) { create_post_with_alerts(user: user, raw: 'Hello @eviltrout') }
    let(:topic) { mention_post.topic }

    it 'notifies a user' do
      expect {
        mention_post
      }.to change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      expect {
        mention_post.revise(mention_post.user, raw: "New raw content that still mentions @eviltrout")
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      expect {
        create_post_with_alerts(user: user, raw: 'second post', topic: topic)
      }.not_to change(user.notifications, :count)
    end

    it "triggers :before_create_notifications_for_users" do
      events = DiscourseEvent.track_events do
        mention_post
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[evil_trout], mention_post])
    end

  it "notification comes from editor is mention is added later" do
    admin = Fabricate(:admin)
      post = create_post_with_alerts(user: user, raw: 'No mention here.')
      expect {
        post.revise(admin, raw: "Mention @eviltrout in this edit.")
      }.to change(evil_trout.notifications, :count)
      n = evil_trout.notifications.last
      expect(n.data_hash["original_username"]).to eq(admin.username)
  end
  end

  describe ".create_notification" do
    let(:topic) { Fabricate(:private_message_topic, user: user, created_at: 1.hour.ago) }
    let(:post) { Fabricate(:post, topic: topic, created_at: 1.hour.ago) }

    it "creates a notification for PMs" do
      post.revise(user, { raw: 'This is the revised post' }, revised_at: Time.zone.now)

      expect {
        PostAlerter.new.create_notification(user, Notification.types[:private_message], post)
      }.to change { user.notifications.count }.by(1)

      expect(user.notifications.last.data_hash["topic_title"]).to eq(topic.title)
    end

    it "keeps the original title for PMs" do
      original_title = topic.title

      post.revise(user, { title: "This is the revised title" }, revised_at: Time.now)

      expect {
        PostAlerter.new.create_notification(user, Notification.types[:private_message], post)
      }.to change { user.notifications.count }.by(1)

      expect(user.notifications.last.data_hash["topic_title"]).to eq(original_title)
    end

    it "triggers :post_notification_alert" do

    end

    it "triggers :before_create_notification" do
      type = Notification.types[:private_message]
      events = DiscourseEvent.track_events do
        PostAlerter.new.create_notification(user, type, post, {})
      end
      expect(events).to include(event_name: :before_create_notification, params: [user, type, post, {}])
    end
  end

  describe "push_notification" do
    let(:mention_post) { create_post_with_alerts(user: user, raw: 'Hello @eviltrout :heart:') }
    let(:topic) { mention_post.topic }

    it "pushes nothing to suspended users" do
      SiteSetting.queue_jobs = true
      SiteSetting.allowed_user_api_push_urls = "https://site.com/push|https://site2.com/push"

      evil_trout.update_columns(suspended_till: 1.year.from_now)

      2.times do |i|
        UserApiKey.create!(user_id: evil_trout.id,
                           client_id: "xxx#{i}",
                           key: "yyy#{i}",
                           application_name: "iPhone#{i}",
                           scopes: ['notifications'],
                           push_url: "https://site2.com/push")
      end

      expect { mention_post }.to_not change { Jobs::PushNotification.jobs.count }
    end

    it "correctly pushes notifications if configured correctly" do
      SiteSetting.allowed_user_api_push_urls = "https://site.com/push|https://site2.com/push"

      2.times do |i|
        UserApiKey.create!(user_id: evil_trout.id,
                           client_id: "xxx#{i}",
                           key: "yyy#{i}",
                           application_name: "iPhone#{i}",
                           scopes: ['notifications'],
                           push_url: "https://site2.com/push")
      end

      body = nil
      headers = nil

      Excon.expects(:post).with { |_req, _body|
        headers = _body[:headers]
        body = _body[:body]
      }.returns("OK")

      payload = {
        "secret_key" => SiteSetting.push_api_secret_key,
        "url" => Discourse.base_url,
        "title" => SiteSetting.title,
        "description" => SiteSetting.site_description,
        "notifications" => [
        {
          'notification_type' => 1,
          'post_number' => 1,
          'topic_title' => topic.title,
          'topic_id' => topic.id,
          'excerpt' => 'Hello @eviltrout ❤',
          'username' => user.username,
          'url' => UrlHelper.absolute(mention_post.url),
          'client_id' => 'xxx0'
        },
        {
          'notification_type' => 1,
          'post_number' => 1,
          'topic_title' => topic.title,
          'topic_id' => topic.id,
          'excerpt' => 'Hello @eviltrout ❤',
          'username' => user.username,
          'url' => UrlHelper.absolute(mention_post.url),
          'client_id' => 'xxx1'
        }
        ]
      }

      mention_post

      expect(JSON.parse(body)).to eq(payload)
      expect(headers["Content-Type"]).to eq('application/json')
    end
  end

  describe "watching_first_post" do
    let(:group) { Fabricate(:group) }
    let(:user) { Fabricate(:user) }
    let(:category) { Fabricate(:category) }
    let(:tag)  { Fabricate(:tag) }
    let(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
    let(:post) { Fabricate(:post, topic: topic) }

    it "doesn't notify people who aren't watching" do
      PostAlerter.post_created(post)
      expect(user.notifications.where(notification_type: Notification.types[:watching_first_post]).count).to eq(0)
    end

    it "notifies the user who is following the first post category" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      PostAlerter.new.after_save_post(post, true)
      expect(user.notifications.where(notification_type: Notification.types[:watching_first_post]).count).to eq(1)
    end

    it "doesn't notify when the record is not new" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      PostAlerter.new.after_save_post(post, false)
      expect(user.notifications.where(notification_type: Notification.types[:watching_first_post]).count).to eq(0)
    end

    it "notifies the user who is following the first post tag" do
      level = TagUser.notification_levels[:watching_first_post]
      TagUser.change(user.id, tag.id, level)
      PostAlerter.post_created(post)
      expect(user.notifications.where(notification_type: Notification.types[:watching_first_post]).count).to eq(1)
    end

    it "notifies the user who is following the first post group" do
      GroupUser.create(group_id: group.id, user_id: user.id)
      GroupUser.create(group_id: group.id, user_id: post.user.id)
      topic.topic_allowed_groups.create(group_id: group.id)

      level = GroupUser.notification_levels[:watching_first_post]
      GroupUser.where(user_id: user.id, group_id: group.id).update_all(notification_level: level)

      PostAlerter.post_created(post)
      expect(user.notifications.where(notification_type: Notification.types[:watching_first_post]).count).to eq(1)
    end

    it "triggers :before_create_notifications_for_users" do
      level = CategoryUser.notification_levels[:watching_first_post]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      events = DiscourseEvent.track_events do
        PostAlerter.new.after_save_post(post, true)
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user], post])
    end
  end

  context "replies" do
    it "triggers :before_create_notifications_for_users" do
      user = Fabricate(:user)
      topic = Fabricate(:topic)
      post = Fabricate(:post, user: user, topic: topic)
      reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)
      events = DiscourseEvent.track_events do
        PostAlerter.post_created(reply)
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user], reply])
    end

    it "notifies about regular reply" do
      user = Fabricate(:user)
      topic = Fabricate(:topic)
      post = Fabricate(:post, user: user, topic: topic)

      reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)
      PostAlerter.post_created(reply)

      expect(user.notifications.where(notification_type: Notification.types[:replied]).count).to eq(1)
    end

    it "doesn't notify regular user about whispered reply" do
      user = Fabricate(:user)
      admin = Fabricate(:admin)

      topic = Fabricate(:topic)
      post = Fabricate(:post, user: user, topic: topic)

      whispered_reply = Fabricate(:post, user: admin, topic: topic, post_type: Post.types[:whisper], reply_to_post_number: 1)
      PostAlerter.post_created(whispered_reply)

      expect(user.notifications.where(notification_type: Notification.types[:replied]).count).to eq(0)
    end

    it "notifies staff user about whispered reply" do
      user = Fabricate(:user)
      admin1 = Fabricate(:admin)
      admin2 = Fabricate(:admin)

      topic = Fabricate(:topic)
      post = Fabricate(:post, user: user, topic: topic)

      whispered_reply1 = Fabricate(:post, user: admin1, topic: topic, post_type: Post.types[:whisper], reply_to_post_number: 1)
      whispered_reply2 = Fabricate(:post, user: admin2, topic: topic, post_type: Post.types[:whisper], reply_to_post_number: 2)
      PostAlerter.post_created(whispered_reply1)
      PostAlerter.post_created(whispered_reply2)

      expect(admin1.notifications.where(notification_type: Notification.types[:replied]).count).to eq(1)
    end
  end

  context "watching" do
    it "triggers :before_create_notifications_for_users" do
      user = Fabricate(:user)
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      post = Fabricate(:post, topic: topic)
      level = CategoryUser.notification_levels[:watching]
      CategoryUser.set_notification_level_for_category(user, level, category.id)
      events = DiscourseEvent.track_events do
        PostAlerter.post_created(post)
      end
      expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user], post])
    end
  end

  context "tags" do
    context "watching" do
      it "triggers :before_create_notifications_for_users" do
        user = Fabricate(:user)
        tag = Fabricate(:tag)
        topic = Fabricate(:topic, tags: [tag])
        post = Fabricate(:post, topic: topic)
        level = TagUser.notification_levels[:watching]
        TagUser.change(user.id, tag.id, level)
        events = DiscourseEvent.track_events do
          PostAlerter.post_created(post)
        end
        expect(events).to include(event_name: :before_create_notifications_for_users, params: [[user], post])
      end
    end
  end

  describe '#extract_linked_users' do
    let(:topic) { Fabricate(:topic) }
    let(:post) { Fabricate(:post, topic: topic) }
    let(:post2) { Fabricate(:post) }

    describe 'when linked post has been deleted' do
      let(:topic_link) do
        TopicLink.create!(
          url: "/t/#{topic.id}",
          topic_id: topic.id,
          link_topic_id: post2.topic.id,
          link_post_id: nil,
          post_id: post.id,
          user: user,
          domain: 'test.com'
        )
      end

      it 'should use the first post of the topic' do
        topic_link
        expect(PostAlerter.new.extract_linked_users(post.reload)).to eq([post2.user])
      end
    end
  end
end
