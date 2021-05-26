# frozen_string_literal: true

require 'rails_helper'

describe PostActionNotifier do

  before do
    PostActionNotifier.enable
    Jobs.run_immediately!
  end

  fab!(:evil_trout) { Fabricate(:evil_trout) }
  fab!(:post) { Fabricate(:post) }

  context 'when editing a post' do
    it 'notifies a user of the revision' do
      expect {
        post.revise(evil_trout, raw: "world is the new body of the message")
      }.to change { post.reload.user.notifications.count }.by(1)
    end

    it 'notifies watching users of revision when post is wiki-ed and first post in topic' do
      SiteSetting.editing_grace_period_max_diff = 1

      post.update!(wiki: true)
      owner = post.user
      user2 = Fabricate(:user)
      user3 = Fabricate(:user)

      TopicUser.change(user2.id, post.topic,
        notification_level: TopicUser.notification_levels[:watching]
      )

      TopicUser.change(user3.id, post.topic,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      expect do
        post.revise(Fabricate(:user), raw: "I made some changes to the wiki!")
      end.to change { Notification.count }.by(2)

      edited_notification_type = Notification.types[:edited]

      expect(Notification.exists?(
        user: owner,
        notification_type: edited_notification_type
      )).to eq(true)

      expect(Notification.exists?(
        user: user2,
        notification_type: edited_notification_type
      )).to eq(true)

      expect do
        post.revise(owner, raw: "I made some changes to the wiki again!")
      end.to change {
        Notification.where(notification_type: edited_notification_type).count
      }.by(1)

      expect(Notification.where(
        user: user2,
        notification_type: edited_notification_type
      ).count).to eq(2)

      expect do
        post.revise(user2, raw: "I changed the wiki totally")
      end.to change {
        Notification.where(notification_type: edited_notification_type).count
      }.by(1)

      expect(Notification.where(
        user: owner,
        notification_type: edited_notification_type
      ).count).to eq(2)
    end

    it 'notifies watching users of revision when topic category allow_unlimited_owner_edits_on_first_post and first post in topic is edited' do
      SiteSetting.editing_grace_period_max_diff = 1

      post.topic.update(category: Fabricate(:category, allow_unlimited_owner_edits_on_first_post: true))
      owner = post.user
      user2 = Fabricate(:user)
      user3 = Fabricate(:user)

      TopicUser.change(user2.id, post.topic,
        notification_level: TopicUser.notification_levels[:watching]
      )

      TopicUser.change(user3.id, post.topic,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      expect do
        post.revise(Fabricate(:user), raw: "I made some changes to the first post!")
      end.to change { Notification.count }.by(2)

      edited_notification_type = Notification.types[:edited]

      expect(Notification.exists?(
        user: owner,
        notification_type: edited_notification_type
      )).to eq(true)

      expect(Notification.exists?(
        user: user2,
        notification_type: edited_notification_type
      )).to eq(true)

      expect do
        post.revise(owner, raw: "I made some changes to the first post again!")
      end.to change {
        Notification.where(notification_type: edited_notification_type).count
      }.by(1)

      expect(Notification.where(
        user: user2,
        notification_type: edited_notification_type
      ).count).to eq(2)

      expect do
        post.revise(user2, raw: "I changed the first post totally")
      end.to change {
        Notification.where(notification_type: edited_notification_type).count
      }.by(1)

      expect(Notification.where(
        user: owner,
        notification_type: edited_notification_type
      ).count).to eq(2)
    end

    it 'stores the revision number with the notification' do
      post.revise(evil_trout, raw: "world is the new body of the message")
      notification_data = JSON.parse post.user.notifications.last.data
      expect(notification_data['revision_number']).to eq post.post_revisions.last.number
    end

    context "edit notifications are disabled" do

      before { SiteSetting.disable_system_edit_notifications = true }

      it 'notifies a user of the revision made by another user' do
        expect {
          post.revise(evil_trout, raw: "world is the new body of the message")
        }.to change(post.user.notifications, :count).by(1)
      end

      it 'does not notify a user of the revision made by the system user' do
        expect {
          post.revise(Discourse.system_user, raw: "world is the new body of the message")
        }.not_to change(post.user.notifications, :count)
      end

    end

    context 'when using plugin API to add custom recipients' do
      let(:lurker) { Fabricate(:user) }

      before do
        plugin = Plugin::Instance.new
        plugin.add_post_revision_notifier_recipients do |post_revision|
          [lurker.id]
        end
      end

      after do
        PostActionNotifier.reset!
      end

      it 'notifies the specified user of the revision' do
        expect {
          post.revise(evil_trout, raw: "world is the new body of the message")
        }.to change {
          lurker.notifications.count
        }.by(1)
      end
    end
  end

  context 'private message' do
    fab!(:user) { Fabricate(:user) }
    fab!(:mention_post) { Fabricate(:post, user: user, raw: 'Hello @eviltrout') }
    let(:topic) do
      topic = mention_post.topic
      topic.update_columns archetype: Archetype.private_message, category_id: nil
      topic
    end

    it "won't notify someone who can't see the post" do
      expect {
        Guardian.any_instance.expects(:can_see?).with(instance_of(Post)).returns(false)
        mention_post
        PostAlerter.post_created(mention_post)
      }.not_to change(evil_trout.notifications, :count)
    end

    it 'creates like notifications' do
      other_user = Fabricate(:user)
      topic.allowed_users << user << other_user
      expect {
        PostActionCreator.like(other_user, mention_post)
      }.to change(user.notifications, :count)
    end
  end

  context 'moderator action post' do
    fab!(:user) { Fabricate(:user) }
    fab!(:first_post) { Fabricate(:post, user: user, raw: 'A useless post for you.') }
    let(:topic) { first_post.topic }

    it 'should not notify anyone' do
      expect {
        Fabricate(:post, topic: topic, raw: 'This topic is CLOSED', post_type: Post.types[:moderator_action])
      }.to_not change { Notification.count }
    end
  end

end
