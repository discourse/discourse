require 'spec_helper'

describe UserAction do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  it { should validate_presence_of :action_type }
  it { should validate_presence_of :user_id }

  describe 'lists' do

    let(:public_post) { Fabricate(:post) }
    let(:public_topic) { public_post.topic }
    let(:user) { Fabricate(:user) }

    let(:private_post) { Fabricate(:post) }
    let(:private_topic) do
      topic = private_post.topic
      topic.update_columns(category_id: nil, archetype: Archetype::private_message)
      topic
    end

    def log_test_action(opts={})
      UserAction.log_action!({
        action_type: UserAction::NEW_PRIVATE_MESSAGE,
        user_id: user.id,
        acting_user_id: user.id,
        target_topic_id: private_topic.id,
        target_post_id: private_post.id,
      }.merge(opts))
    end

    before do
      # Create some test data using a helper
      log_test_action
      log_test_action(action_type: UserAction::GOT_PRIVATE_MESSAGE)
      log_test_action(action_type: UserAction::NEW_TOPIC, target_topic_id: public_topic.id, target_post_id: public_post.id)
      log_test_action(action_type: UserAction::BOOKMARK)
    end

    def stats_for_user(viewer=nil)
      UserAction.stats(user.id, Guardian.new(viewer)).map{|r| r["action_type"].to_i}.sort
    end

    def stream_count(viewer=nil)
      UserAction.stream(user_id: user.id, guardian: Guardian.new(viewer)).count
    end

    it 'includes the events correctly' do
      mystats = stats_for_user(user)
      expecting = [UserAction::NEW_TOPIC, UserAction::NEW_PRIVATE_MESSAGE, UserAction::GOT_PRIVATE_MESSAGE, UserAction::BOOKMARK].sort
      mystats.should == expecting
      stream_count(user).should == 4

      other_stats = stats_for_user
      expecting = [UserAction::NEW_TOPIC]
      stream_count.should == 1

      other_stats.should == expecting

      public_topic.trash!(user)
      stats_for_user.should == []
      stream_count.should == 0

      # groups
      category = Fabricate(:category, read_restricted: true)

      public_topic.recover!
      public_topic.category = category
      public_topic.save

      stats_for_user.should == []
      stream_count.should == 0

      group = Fabricate(:group)
      u = Fabricate(:coding_horror)
      group.add(u)
      group.save

      category.set_permissions(group => :full)
      category.save

      stats_for_user(u).should == [UserAction::NEW_TOPIC]
      stream_count(u).should == 1

      # duplicate should not exception out
      log_test_action

      # recategorize belongs to the right user
      category2 = Fabricate(:category)
      admin = Fabricate(:admin)
      public_post.revise(admin, { category_id: category2.id})

      action = UserAction.stream(user_id: public_topic.user_id, guardian: Guardian.new)[0]
      action.acting_user_id.should == admin.id
      action.action_type.should == UserAction::EDIT
    end

  end

  describe 'when user likes' do

    let!(:post) { Fabricate(:post) }
    let(:likee) { post.user }
    let(:liker) { Fabricate(:coding_horror) }

    def likee_stream
      UserAction.stream(user_id: likee.id, guardian: Guardian.new)
    end

    before do
      @old_count = likee_stream.count
    end

    it "creates a new stream entry" do
      PostAction.act(liker, post, PostActionType.types[:like])
      likee_stream.count.should == @old_count + 1
    end

    context "successful like" do
      before do
        PostAction.act(liker, post, PostActionType.types[:like])
        @liker_action = liker.user_actions.find_by(action_type: UserAction::LIKE)
        @likee_action = likee.user_actions.find_by(action_type: UserAction::WAS_LIKED)
      end

      it 'should result in correct data assignment' do
        @liker_action.should_not == nil
        @likee_action.should_not == nil
        likee.user_stat.reload.likes_received.should == 1
        liker.user_stat.reload.likes_given.should == 1

        PostAction.remove_act(liker, post, PostActionType.types[:like])
        likee.user_stat.reload.likes_received.should == 0
        liker.user_stat.reload.likes_given.should == 0
      end

    end

    context "liking a private message" do

      before do
        post.topic.update_columns(category_id: nil, archetype: Archetype::private_message)
      end

      it "doesn't add the entry to the stream" do
        PostAction.act(liker, post, PostActionType.types[:like])
        likee_stream.count.should_not == @old_count + 1
      end

    end

  end

  describe 'when a user posts a new topic' do
    def process_alerts(post)
      PostAlerter.post_created(post)
    end

    before do
      @post = Fabricate(:old_post)
      process_alerts(@post)
    end

    describe 'topic action' do
      before do
        @action = @post.user.user_actions.find_by(action_type: UserAction::NEW_TOPIC)
      end
      it 'should exist' do
        @action.should_not == nil
        @action.created_at.should be_within(1).of(@post.topic.created_at)
      end
    end

    it 'should not log a post user action' do
      @post.user.user_actions.find_by(action_type: UserAction::REPLY).should == nil
    end


    describe 'when another user posts on the topic' do
      before do
        @other_user = Fabricate(:coding_horror)
        @mentioned = Fabricate(:admin)
        @response = Fabricate(:post, reply_to_post_number: 1, topic: @post.topic, user: @other_user, raw: "perhaps @#{@mentioned.username} knows how this works?")

        process_alerts(@response)
      end

      it 'should log user actions correctly' do
        @response.user.user_actions.find_by(action_type: UserAction::REPLY).should_not == nil
        @post.user.user_actions.find_by(action_type: UserAction::RESPONSE).should_not == nil
        @mentioned.user_actions.find_by(action_type: UserAction::MENTION).should_not == nil
        @post.user.user_actions.joins(:target_post).where('posts.post_number = 2').count.should == 1
      end

      it 'should not log a double notification for a post edit' do
        @response.raw = "here it goes again"
        @response.save!
        @response.user.user_actions.where(action_type: UserAction::REPLY).count.should == 1
      end

    end
  end

  describe 'when user bookmarks' do
    before do
      @post = Fabricate(:post)
      @user = @post.user
      PostAction.act(@user, @post, PostActionType.types[:bookmark])
      @action = @user.user_actions.find_by(action_type: UserAction::BOOKMARK)
    end

    it 'should create a bookmark action correctly' do
      @action.action_type.should == UserAction::BOOKMARK
      @action.target_post_id.should == @post.id
      @action.acting_user_id.should == @user.id
      @action.user_id.should == @user.id

      PostAction.remove_act(@user, @post, PostActionType.types[:bookmark])
      @user.user_actions.find_by(action_type: UserAction::BOOKMARK).should == nil
    end
  end

  describe 'private messages' do

    let(:user) do
      Fabricate(:user)
    end

    let(:target_user) do
      Fabricate(:user)
    end

    let(:private_message) do
      PostCreator.create( user,
                          raw: 'this is a private message',
                          title: 'this is the pm title',
                          target_usernames: target_user.username,
                          archetype: Archetype::private_message
                        )
    end

    let!(:response) do
      PostCreator.create(user, raw: 'oops I forgot to mention this', topic_id: private_message.topic_id)
    end

    let!(:private_message2) do
      PostCreator.create( target_user,
                          raw: 'this is a private message',
                          title: 'this is the pm title',
                          target_usernames: user.username,
                          archetype: Archetype::private_message
                        )
    end

  end

  describe 'synchronize_starred' do
    it 'corrects out of sync starred' do
      post = Fabricate(:post)
      post.topic.toggle_star(post.user, true)
      UserAction.delete_all

      UserAction.log_action!(
        action_type: UserAction::STAR,
        user_id: post.user.id,
        acting_user_id: post.user.id,
        target_topic_id: 99,
        target_post_id: -1,
      )

      UserAction.log_action!(
        action_type: UserAction::STAR,
        user_id: Fabricate(:user).id,
        acting_user_id: post.user.id,
        target_topic_id: post.topic_id,
        target_post_id: -1,
      )

      UserAction.synchronize_starred

      actions = UserAction.all.to_a

      actions.length.should == 1
      actions.first.action_type.should == UserAction::STAR
      actions.first.user_id.should == post.user.id
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
      action.target_topic_id.should == post.topic_id
    end
  end
end
