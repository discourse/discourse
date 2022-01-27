# frozen_string_literal: true

require 'rails_helper'

describe UserAction do
  fab!(:coding_horror) { Fabricate(:coding_horror) }

  before do
    UserActionManager.enable
  end

  it { is_expected.to validate_presence_of :action_type }
  it { is_expected.to validate_presence_of :user_id }

  describe '#stream' do

    fab!(:public_post) { Fabricate(:post) }
    let(:public_topic) { public_post.topic }
    fab!(:user) { Fabricate(:user) }

    fab!(:private_post) { Fabricate(:post) }
    let(:private_topic) do
      topic = private_post.topic
      topic.update_columns(category_id: nil, archetype: Archetype::private_message)
      TopicAllowedUser.create(topic_id: topic.id, user_id: user.id)
      topic
    end

    def log_test_action(opts = {})
      UserAction.log_action!({
        action_type: UserAction::NEW_PRIVATE_MESSAGE,
        user_id: user.id,
        acting_user_id: user.id,
        target_topic_id: private_topic.id,
        target_post_id: private_post.id,
      }.merge(opts))
    end

    it "allows publishing when group is deleted" do
      public_topic.category.update!(read_restricted: true)

      m = MessageBus.track_publish("/u/#{user.username_lower}") do
        log_test_action(target_topic_id: public_topic.id, target_post_id: public_post.id)
      end

      expect(m[0].group_ids).to eq([Group::AUTO_GROUPS[:admins]])
      expect(m[0].user_ids).to eq([user.id])
    end

    describe "integration" do
      def stats_for_user(viewer = nil)
        UserAction.stats(user.id, Guardian.new(viewer)).map { |r| r.action_type.to_i }.sort
      end

      def stream(viewer = nil)
        UserAction.stream(user_id: user.id, guardian: Guardian.new(viewer))
      end

      it 'includes the events correctly' do
        # Create some test data using a helper
        log_test_action
        log_test_action(action_type: UserAction::GOT_PRIVATE_MESSAGE)
        log_test_action(action_type: UserAction::NEW_TOPIC, target_topic_id: public_topic.id, target_post_id: public_post.id)
        log_test_action(action_type: UserAction::BOOKMARK)

        Jobs.run_immediately!
        PostActionNotifier.enable

        mystats = stats_for_user(user)
        expecting = [UserAction::NEW_TOPIC, UserAction::NEW_PRIVATE_MESSAGE, UserAction::GOT_PRIVATE_MESSAGE, UserAction::BOOKMARK].sort
        expect(mystats).to eq(expecting)

        expect(stream(user).map(&:action_type))
          .to contain_exactly(*expecting)

        other_stats = stats_for_user
        expecting = [UserAction::NEW_TOPIC]
        expect(stream.map(&:action_type)).to contain_exactly(*expecting)
        expect(other_stats).to eq(expecting)

        public_topic.trash!(user)
        expect(stats_for_user).to eq([])
        expect(stream).to eq([])

        # groups
        category = Fabricate(:category, read_restricted: true)

        public_topic.recover!
        public_topic.update!(category: category)

        expect(stats_for_user).to eq([])
        expect(stream).to eq([])

        group = Fabricate(:group)
        u = coding_horror
        group.add(u)

        category.set_permissions(group => :full)
        category.save!

        expecting = [UserAction::NEW_TOPIC]
        expect(stats_for_user(u)).to eq(expecting)
        expect(stream(u).map(&:action_type)).to contain_exactly(*expecting)

        # duplicate should not exception out
        log_test_action

        # recategorize belongs to the right user
        category2 = Fabricate(:category)
        admin = Fabricate(:admin)
        public_post.revise(admin, category_id: category2.id)

        action = UserAction.stream(user_id: public_topic.user_id, guardian: Guardian.new)[0]
        expect(action.acting_user_id).to eq(admin.id)
        expect(action.action_type).to eq(UserAction::EDIT)
      end
    end

    describe 'assignments' do
      let(:stream) do
        UserAction.stream(user_id: user.id, guardian: Guardian.new(user))
      end

      before do
        log_test_action(action_type: UserAction::ASSIGNED)
        private_post.custom_fields ||= {}
        private_post.custom_fields["action_code_who"] = 'testing'
        private_post.custom_fields["random_field"] = 'random_value'
        private_post.save!
      end

      it 'should include the right attributes in the stream' do
        expect(stream.count).to eq(1)

        user_action_row = stream.first

        expect(user_action_row.action_type).to eq(UserAction::ASSIGNED)
        expect(user_action_row.action_code_who).to eq('testing')
      end
    end

    describe "mentions" do
      before do
        log_test_action(action_type: UserAction::MENTION)
      end

      let(:stream) do
        UserAction.stream(
          user_id: user.id,
          guardian: Guardian.new(user)
        )
      end

      it "is returned by the stream" do
        expect(stream.count).to eq(1)
        expect(stream.first.action_type).to eq(UserAction::MENTION)
      end

      it "isn't returned when mentions aren't enabled" do
        SiteSetting.enable_mentions = false
        expect(stream).to be_blank
      end
    end

  end

  describe 'when user likes' do

    fab!(:post) { Fabricate(:post) }
    let(:likee) { post.user }
    fab!(:liker) { coding_horror }

    def likee_stream
      UserAction.stream(user_id: likee.id, guardian: Guardian.new)
    end

    before do
      @old_count = likee_stream.count
    end

    it "creates a new stream entry" do
      PostActionCreator.like(liker, post)
      expect(likee_stream.count).to eq(@old_count + 1)
    end

    context "successful like" do
      before do
        PostActionCreator.like(liker, post)
        @liker_action = liker.user_actions.find_by(action_type: UserAction::LIKE)
        @likee_action = likee.user_actions.find_by(action_type: UserAction::WAS_LIKED)
      end

      it 'should result in correct data assignment' do
        expect(@liker_action).not_to eq(nil)
        expect(@likee_action).not_to eq(nil)
        expect(likee.user_stat.reload.likes_received).to eq(1)
        expect(liker.user_stat.reload.likes_given).to eq(1)

        PostActionDestroyer.destroy(liker, post, :like)
        expect(likee.user_stat.reload.likes_received).to eq(0)
        expect(liker.user_stat.reload.likes_given).to eq(0)
      end

      context 'private message' do
        fab!(:post) { Fabricate(:private_message_post) }
        let(:likee) { post.topic.topic_allowed_users.first.user }
        let(:liker) { post.topic.topic_allowed_users.last.user }

        it 'should not increase user stats' do
          expect(@liker_action).not_to eq(nil)
          expect(liker.user_stat.reload.likes_given).to eq(0)
          expect(@likee_action).not_to eq(nil)
          expect(likee.user_stat.reload.likes_received).to eq(0)

          PostActionDestroyer.destroy(liker, post, :like)
          expect(liker.user_stat.reload.likes_given).to eq(0)
          expect(likee.user_stat.reload.likes_received).to eq(0)
        end
      end

    end

    context "liking a private message" do

      before do
        post.topic.update_columns(category_id: nil, archetype: Archetype::private_message)
      end

      it "doesn't add the entry to the stream" do
        PostActionCreator.like(liker, post)
        expect(likee_stream.count).not_to eq(@old_count + 1)
      end

    end

  end

  describe 'when a user posts a new topic' do
    before do
      freeze_time(100.days.ago) do
        @post = create_post
        PostAlerter.post_created(@post)
      end
    end

    describe 'topic action' do
      it 'should exist' do
        @action = @post.user.user_actions.find_by(action_type: UserAction::NEW_TOPIC)

        expect(@action).not_to eq(nil)
        expect(@action.created_at).to eq_time(@post.topic.created_at)
      end
    end

    it 'should not log a post user action' do
      expect(@post.user.user_actions.find_by(action_type: UserAction::REPLY)).to eq(nil)
    end

    describe 'when another user posts on the topic' do
      before do
        @other_user = coding_horror
        @mentioned = Fabricate(:admin)

        @response = PostCreator.new(@other_user, reply_to_post_number: 1, topic_id: @post.topic_id, raw: "perhaps @#{@mentioned.username} knows how this works?").create

        PostAlerter.post_created(@response)
      end

      it 'should log user actions correctly' do
        expect(@response.user.user_actions.find_by(action_type: UserAction::REPLY)).not_to eq(nil)
        expect(@post.user.user_actions.find_by(action_type: UserAction::RESPONSE)).not_to eq(nil)
        expect(@mentioned.user_actions.find_by(action_type: UserAction::MENTION)).not_to eq(nil)
        expect(@post.user.user_actions.joins(:target_post).where('posts.post_number = 2').count).to eq(1)
      end

      it 'should not log a double notification for a post edit' do
        @response.raw = "here it goes again"
        @response.save!
        expect(@response.user.user_actions.where(action_type: UserAction::REPLY).count).to eq(1)
      end

    end
  end

  describe 'when user bookmarks' do
    before do
      @post = Fabricate(:post)
      @user = @post.user
      PostActionCreator.create(@user, @post, :bookmark)
      @action = @user.user_actions.find_by(action_type: UserAction::BOOKMARK)
    end

    it 'creates the bookmark, and removes it properly' do
      expect(@action.action_type).to eq(UserAction::BOOKMARK)
      expect(@action.target_post_id).to eq(@post.id)
      expect(@action.acting_user_id).to eq(@user.id)
      expect(@action.user_id).to eq(@user.id)

      PostActionDestroyer.destroy(@user, @post, :bookmark)
      expect(@user.user_actions.find_by(action_type: UserAction::BOOKMARK)).to eq(nil)
    end
  end

  describe 'secures private messages' do

    fab!(:user) do
      Fabricate(:user)
    end

    fab!(:user2) do
      Fabricate(:user)
    end

    let(:private_message) do
      PostCreator.create(user,
                          raw: 'this is a private message',
                          title: 'this is the pm title',
                          target_usernames: user2.username,
                          archetype: Archetype::private_message
                        )
    end

    def count_bookmarks
      UserAction.stream(
        user_id: user.id,
        action_types: [UserAction::BOOKMARK],
        ignore_private_messages: false,
        guardian: Guardian.new(user)
      ).count
    end

    it 'correctly secures stream' do
      PostActionCreator.create(user, private_message, :bookmark)

      expect(count_bookmarks).to eq(1)

      private_message.topic.topic_allowed_users.where(user_id: user.id).destroy_all

      expect(count_bookmarks).to eq(0)

      group = Fabricate(:group)
      group.add(user)
      private_message.topic.topic_allowed_groups.create(group_id: group.id)

      expect(count_bookmarks).to eq(1)

    end

  end

  describe 'synchronize_target_topic_ids' do
    it 'correct target_topic_id' do
      post = Fabricate(:post)

      action = UserAction.log_action!(
        action_type: UserAction::NEW_PRIVATE_MESSAGE,
        user_id: post.user.id,
        acting_user_id: post.user.id,
        target_topic_id: -1,
        target_post_id: post.id,
      )

      UserAction.log_action!(
        action_type: UserAction::NEW_PRIVATE_MESSAGE,
        user_id: post.user.id,
        acting_user_id: post.user.id,
        target_topic_id: -2,
        target_post_id: post.id,
      )

      UserAction.synchronize_target_topic_ids

      action.reload
      expect(action.target_topic_id).to eq(post.topic_id)
    end
  end
end
