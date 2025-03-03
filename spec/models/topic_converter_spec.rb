# frozen_string_literal: true

RSpec.describe TopicConverter do
  describe "convert_to_public_topic" do
    fab!(:admin)
    fab!(:author) { Fabricate(:user) }
    fab!(:category) { Fabricate(:category, topic_count: 1) }
    fab!(:private_message) { Fabricate(:private_message_topic, user: author) } # creates a topic without a first post
    let(:first_post) do
      create_post(user: author, topic: private_message, allow_uncategorized_topics: false)
    end
    let(:other_user) { private_message.topic_allowed_users.find { |u| u.user != author }.user }

    let(:uncategorized_category) { Category.find(SiteSetting.uncategorized_category_id) }

    context "with success" do
      it "converts private message to regular topic" do
        SiteSetting.allow_uncategorized_topics = true
        topic = nil

        _pm_post_2 = Fabricate(:post, topic: private_message, user: author)
        _pm_post_3 = Fabricate(:post, topic: private_message, user: author)

        other_pm = Fabricate(:private_message_post).topic
        other_pm_post = Fabricate(:private_message_post, topic: other_pm)
        other_pm_post_2 =
          Fabricate(:private_message_post, topic: other_pm, user: other_pm_post.user)

        expect do
          topic = TopicConverter.new(first_post.topic, admin).convert_to_public_topic
          topic.reload
        end.to change { uncategorized_category.reload.topic_count }.by(1).and change {
                author.reload.topic_count
              }.from(0).to(1).and change { author.reload.post_count }.from(0).to(2)

        # Ensure query does not affect users from other topics or posts as DB query to update count is quite complex.
        expect(other_pm.user.topic_count).to eq(0)
        expect(other_pm.user.post_count).to eq(0)
        expect(other_pm_post.user.topic_count).to eq(0)
        expect(other_pm_post.user.post_count).to eq(0)

        expect(topic).to be_valid
        expect(topic.archetype).to eq("regular")
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      context "when uncategorized category is not allowed" do
        before do
          SiteSetting.allow_uncategorized_topics = false
          category.update!(read_restricted: false)
        end

        it "should convert private message into the right category" do
          topic = TopicConverter.new(first_post.topic, admin).convert_to_public_topic
          topic.reload

          expect(topic).to be_valid
          expect(topic.archetype).to eq("regular")

          first_category =
            Category
              .where.not(id: SiteSetting.uncategorized_category_id)
              .where(read_restricted: false)
              .order("id asc")
              .first

          expect(topic.category_id).to eq(first_category.id)
          expect(topic.category.topic_count).to eq(2)
        end
      end

      context "when a custom category_id is given" do
        it "should convert private message into the right category" do
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
        expect(private_message.user.user_stat.post_count).to eq(0)
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
          expect(
            author.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count,
          ).to eq(0)
          expect(author.user_actions.where(action_type: UserAction::NEW_TOPIC).count).to eq(1)
          expect(
            other_user.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count,
          ).to eq(0)
          expect(
            other_user.user_actions.where(action_type: UserAction::GOT_PRIVATE_MESSAGE).count,
          ).to eq(0)
          expect(other_user.user_actions.where(action_type: UserAction::REPLY).count).to eq(1)
        end
      end

      it "deletes notifications for users not allowed to see the topic" do
        staff_category = Fabricate(:private_category, group: Group[:staff])
        user_notification =
          Fabricate(:mentioned_notification, post: first_post, user: Fabricate(:user))
        admin_notification =
          Fabricate(:mentioned_notification, post: first_post, user: Fabricate(:admin))

        Jobs.run_immediately!
        TopicConverter.new(first_post.topic, admin).convert_to_public_topic(staff_category.id)

        expect(Notification.exists?(user_notification.id)).to eq(false)
        expect(Notification.exists?(admin_notification.id)).to eq(true)
      end
    end
  end

  describe "convert_to_private_message" do
    fab!(:admin)
    fab!(:author) { Fabricate(:user) }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: author, category_id: category.id) }
    fab!(:post) { Fabricate(:post, topic: topic, user: topic.user) }

    context "with success" do
      it "converts regular topic to private message" do
        private_message = topic.convert_to_private_message(post.user)
        expect(private_message).to be_valid
        expect(topic.archetype).to eq("private_message")
        expect(topic.category_id).to eq(nil)
        expect(category.reload.topic_count).to eq(0)
      end

      it "converts unlisted topic to private message" do
        topic.update_status("visible", false, admin)
        private_message = topic.convert_to_private_message(post.user)

        expect(private_message).to be_valid
        expect(topic.archetype).to eq("private_message")
        expect(topic.category_id).to eq(nil)
        expect(topic.user.post_count).to eq(0)
        expect(topic.user.topic_count).to eq(0)
        expect(category.reload.topic_count).to eq(0)
      end

      it "updates user stats when converting topic to private message" do
        _post_2 = Fabricate(:post, topic: topic, user: author)
        _post_3 = Fabricate(:post, topic: topic, user: author)

        other_topic = Fabricate(:post).topic
        other_post = Fabricate(:post, topic: other_topic)

        topic_user = TopicUser.create!(user_id: author.id, topic_id: topic.id, posted: true)

        expect do topic.convert_to_private_message(admin) end.to change {
          author.reload.post_count
        }.from(2).to(0).and change { author.reload.topic_count }.from(1).to(0)

        # Ensure query does not affect users from other topics or posts as DB query to update count is quite complex.
        expect(other_topic.user.post_count).to eq(0)
        expect(other_topic.user.topic_count).to eq(1)
        expect(other_post.user.post_count).to eq(1)
        expect(other_post.user.topic_count).to eq(0)

        expect(topic.reload.topic_allowed_users.where(user_id: author.id).count).to eq(1)
        expect(topic_user.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "invites only users with regular posts" do
        post2 = Fabricate(:post, topic: topic)
        Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
        Fabricate(:post, topic: topic, post_type: Post.types[:small_action])

        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.pluck(:user_id)).to contain_exactly(
          admin.id,
          post.user_id,
          post2.user_id,
        )
      end

      it "changes user_action type" do
        Jobs.run_immediately!
        UserActionManager.enable
        topic.convert_to_private_message(admin)
        expect(author.user_actions.where(action_type: UserAction::NEW_TOPIC).count).to eq(0)
        expect(author.user_actions.where(action_type: UserAction::NEW_PRIVATE_MESSAGE).count).to eq(
          1,
        )
      end

      it "deletes notifications for users not allowed to see the message" do
        user_notification = Fabricate(:mentioned_notification, post: post, user: Fabricate(:user))
        admin_notification = Fabricate(:mentioned_notification, post: post, user: Fabricate(:admin))

        Jobs.run_immediately!
        topic.convert_to_private_message(admin)

        expect(Notification.exists?(user_notification.id)).to eq(false)
        expect(Notification.exists?(admin_notification.id)).to eq(true)
      end

      it "limits PM participants" do
        SiteSetting.max_allowed_message_recipients = 2
        Fabricate(:post, topic: topic)
        Fabricate(:post, topic: topic)

        private_message = topic.convert_to_private_message(post.user)

        # Skips posters and just adds the acting user
        expect(private_message.topic_allowed_users.count).to eq(1)
      end

      it "includes the poster of a single-post topic" do
        moderator = Fabricate(:moderator)
        private_message = topic.convert_to_private_message(moderator)
        expect(private_message.allowed_users).to match_array([topic.user, moderator])
      end
    end

    context "when topic has replies" do
      let(:replied_user) { Fabricate(:coding_horror) }

      before do
        create_post(topic: topic, user: replied_user)
        topic.reload
      end

      it "adds users who replied to topic in Private Message" do
        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.where(user_id: replied_user.id).count).to eq(1)
        expect(topic.reload.user.user_stat.post_count).to eq(0)
      end
    end

    context "when user already exists in topic_allowed_users table" do
      before { topic.topic_allowed_users.create!(user_id: admin.id) }

      it "works" do
        topic.convert_to_private_message(admin)

        expect(topic.reload.archetype).to eq("private_message")
      end
    end

    context "with user_profiles with newly converted PM as featured topic" do
      it "sets all matching user_profile featured topic ids to nil" do
        author.user_profile.update(featured_topic: topic)
        topic.convert_to_private_message(admin)

        expect(author.user_profile.reload.featured_topic).to eq(nil)
      end
    end
  end
end
