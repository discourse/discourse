# frozen_string_literal: true

require 'rails_helper'

describe TopicConverter do

  context 'convert_to_public_topic' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:author) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category, topic_count: 1) }
    fab!(:private_message) { Fabricate(:private_message_topic, user: author) } # creates a topic without a first post
    let(:first_post) { create_post(user: author, topic: private_message) }
    let(:other_user) { private_message.topic_allowed_users.find { |u| u.user != author }.user }

    let(:uncategorized_category) do
      Category.find(SiteSetting.uncategorized_category_id)
    end

    context 'success' do
      it "converts private message to regular topic" do
        SiteSetting.allow_uncategorized_topics = true
        topic = nil

        expect do
          topic = TopicConverter.new(first_post.topic, admin).convert_to_public_topic
          topic.reload
        end.to change { uncategorized_category.reload.topic_count }.by(1)

        expect(topic).to be_valid
        expect(topic.archetype).to eq("regular")
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      describe 'when uncategorized category is not allowed' do
        before do
          SiteSetting.allow_uncategorized_topics = false
          category.update!(read_restricted: false)
        end

        it 'should convert private message into the right category' do
          topic = TopicConverter.new(first_post.topic, admin).convert_to_public_topic
          topic.reload

          expect(topic).to be_valid
          expect(topic.archetype).to eq("regular")

          first_category = Category.where.not(id: SiteSetting.uncategorized_category_id)
            .where(read_restricted: false).order('id asc').first

          expect(topic.category_id).to eq(first_category.id)
          expect(topic.category.topic_count).to eq(2)
        end
      end

      describe 'when a custom category_id is given' do
        it 'should convert private message into the right category' do
          topic = TopicConverter.new(first_post.topic, admin).convert_to_public_topic(category.id)

          expect(topic.reload.category).to eq(category)
          expect(topic.category.topic_count).to eq(2)
        end
      end

      it "updates user stats" do
        first_post
        topic_user = TopicUser.find_by(user_id: author.id, topic_id: private_message.id)
        expect(private_message.user.user_stat.topic_count).to eq(0)
        expect(private_message.user.user_stat.post_count).to eq(0)
        private_message.convert_to_public_topic(admin)
        expect(private_message.reload.user.user_stat.topic_count).to eq(1)
        expect(private_message.user.user_stat.post_count).to eq(1)
        expect(topic_user.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      context "with a reply" do
        before do
          Jobs.run_immediately!
          UserActionManager.enable
          first_post
          create_post(topic: private_message, user: other_user)
          private_message.reload
        end

        it "updates UserActions" do
          TopicConverter.new(private_message, admin).convert_to_public_topic
          expect(author.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count).to eq(0)
          expect(author.user_actions.where(action_type: UserAction::NEW_TOPIC).count).to eq(1)
          expect(other_user.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count).to eq(0)
          expect(other_user.user_actions.where(action_type: UserAction::GOT_PRIVATE_MESSAGE).count).to eq(0)
          expect(other_user.user_actions.where(action_type: UserAction::REPLY).count).to eq(1)
        end
      end

      it "deletes notifications for users not allowed to see the topic" do
        staff_category = Fabricate(:private_category, group: Group[:staff])
        user_notification = Fabricate(:mentioned_notification, post: first_post, user: Fabricate(:user))
        admin_notification = Fabricate(:mentioned_notification, post: first_post, user: Fabricate(:admin))

        Jobs.run_immediately!
        TopicConverter.new(first_post.topic, admin).convert_to_public_topic(staff_category.id)

        expect(Notification.exists?(user_notification.id)).to eq(false)
        expect(Notification.exists?(admin_notification.id)).to eq(true)
      end
    end
  end

  context 'convert_to_private_message' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:author) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category) }
    fab!(:topic) { Fabricate(:topic, user: author, category_id: category.id) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    context 'success' do
      it "converts regular topic to private message" do
        private_message = topic.convert_to_private_message(post.user)
        expect(private_message).to be_valid
        expect(topic.archetype).to eq("private_message")
        expect(topic.category_id).to eq(nil)
        expect(category.reload.topic_count).to eq(0)
      end

      it "updates user stats" do
        Fabricate(:post, topic: topic, user: author)
        topic_user = TopicUser.create!(user_id: author.id, topic_id: topic.id, posted: true)
        author.user_stat.topic_count = 1
        author.user_stat.save
        expect(topic.user.user_stat.topic_count).to eq(1)
        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.where(user_id: author.id).count).to eq(1)
        expect(topic.reload.user.user_stat.topic_count).to eq(0)
        expect(topic_user.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "changes user_action type" do
        Jobs.run_immediately!
        UserActionManager.enable
        topic.convert_to_private_message(admin)
        expect(author.user_actions.where(action_type: UserAction::NEW_TOPIC).count).to eq(0)
        expect(author.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count).to eq(1)
      end

      it "deletes notifications for users not allowed to see the message" do
        user_notification = Fabricate(:mentioned_notification, post: post, user: Fabricate(:user))
        admin_notification = Fabricate(:mentioned_notification, post: post, user: Fabricate(:admin))

        Jobs.run_immediately!
        topic.convert_to_private_message(admin)

        expect(Notification.exists?(user_notification.id)).to eq(false)
        expect(Notification.exists?(admin_notification.id)).to eq(true)
      end
    end

    context 'topic has replies' do
      before do
        @replied_user = Fabricate(:coding_horror)
        create_post(topic: topic, user: @replied_user)
        topic.reload
      end

      it 'adds users who replied to topic in Private Message' do
        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.where(user_id: @replied_user.id).count).to eq(1)
        expect(topic.reload.user.user_stat.post_count).to eq(0)
      end
    end

    context 'when user already exists in topic_allowed_users table' do
      before do
        topic.topic_allowed_users.create!(user_id: admin.id)
      end

      it "works" do
        topic.convert_to_private_message(admin)

        expect(topic.reload.archetype).to eq("private_message")
      end
    end

    context 'user_profiles with newly converted PM as featured topic' do
      it "sets all matching user_profile featured topic ids to nil" do
        author.user_profile.update(featured_topic: topic)
        topic.convert_to_private_message(admin)

        expect(author.user_profile.reload.featured_topic).to eq(nil)
      end
    end

  end
end
