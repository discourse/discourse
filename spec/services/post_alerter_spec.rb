require 'rails_helper'

describe PostAlerter do

  let!(:evil_trout) { Fabricate(:evil_trout) }
  let(:user) { Fabricate(:user) }

  def create_post_with_alerts(args={})
    post = Fabricate(:post, args)
    PostAlerter.post_created(post)
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

  context 'likes' do
    it 'does not double notify users on likes' do
      ActiveRecord::Base.observers.enable :all

      post = Fabricate(:post, raw: 'I love waffles')
      PostAction.act(evil_trout, post, PostActionType.types[:like])

      admin = Fabricate(:admin)
      post.revise(admin, {raw: 'I made a revision'})

      PostAction.act(admin, post, PostActionType.types[:like])

      # one like and one edit notification
      expect(Notification.count(post_number: 1, topic_id: post.topic_id)).to eq(2)
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
        p1.revise(p1.user, { raw: '[quote="Evil Trout, post:1"]whatup now?[/quote]' })
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the poster" do
      topic = create_post_with_alerts.topic
      expect {
        Fabricate(:post, topic: topic, user: topic.user, raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]')
      }.not_to change(topic.user.notifications, :count)
    end
  end

  context 'linked' do
    it "will notify correctly on linking" do
      post1 = create_post
      user = post1.user
      create_post(raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      expect(user.notifications.count).to eq(1)

      topic = Fabricate(:topic)

      watcher = Fabricate(:user)
      TopicUser.create!(user_id: watcher.id, topic_id: topic.id, notification_level: TopicUser.notification_levels[:watching])

      create_post(topic_id: topic.id, user: user, raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      user.reload
      expect(user.notifications.count).to eq(1)

      expect(watcher.notifications.count).to eq(1)

      # don't notify on reflection
      post1.reload
      expect(PostAlerter.new.extract_linked_users(post1).length).to eq(0)

    end
  end

  context '@group mentions' do

    it 'notifies users correctly' do

      group = Fabricate(:group, name: 'group', alias_level: Group::ALIAS_LEVELS[:everyone])
      group.add(evil_trout)

      expect {
        create_post_with_alerts(raw: "Hello @group how are you?")
      }.to change(evil_trout.notifications, :count).by(1)

      expect(GroupMention.count).to eq(1)

      Fabricate(:group, name: 'group-alt', alias_level: Group::ALIAS_LEVELS[:everyone])

      expect {
        create_post_with_alerts(raw: "Hello, @group-alt should not trigger a notification?")
      }.to change(evil_trout.notifications, :count).by(0)

      expect(GroupMention.count).to eq(2)

      group.update_columns(alias_level: Group::ALIAS_LEVELS[:members_mods_and_admins])
      expect {
        create_post_with_alerts(raw: "Hello @group you are not mentionable")
      }.to change(evil_trout.notifications, :count).by(0)

      expect(GroupMention.count).to eq(3)
    end
  end

  context '@mentions' do

    let(:mention_post) { create_post_with_alerts(user: user, raw: 'Hello @eviltrout')}
    let(:topic) { mention_post.topic }

    it 'notifies a user' do
      expect {
        mention_post
      }.to change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      expect {
        mention_post.revise(mention_post.user, { raw: "New raw content that still mentions @eviltrout" })
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      expect {
        create_post_with_alerts(user: user, raw: 'second post', topic: topic)
      }.not_to change(user.notifications, :count)
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
  end

end
