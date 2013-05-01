require 'spec_helper'

describe UserAction do

  it { should validate_presence_of :action_type }
  it { should validate_presence_of :user_id }


  describe 'lists' do

    let(:public_post) { Fabricate(:post) }
    let(:public_topic) { public_post.topic }
    let(:user) { Fabricate(:user) }

    let(:private_post) { Fabricate(:post) }
    let(:private_topic) do
      topic = private_post.topic
      topic.update_column(:archetype, Archetype::private_message)
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

      public_topic.destroy
      stats_for_user.should == []
      stream_count.should == 0

      # groups

      category = Fabricate(:category, secure: true)

      public_topic.recover
      public_topic.category = category
      public_topic.save

      stats_for_user.should == []
      stream_count.should == 0

      group = Fabricate(:group)
      u = Fabricate(:coding_horror)
      group.add(u)
      group.save

      category.allow(group)
      category.save

      stats_for_user(u).should == [UserAction::NEW_TOPIC]
      stream_count(u).should == 1

    end
  end

  it 'calls the message bus observer' do
    MessageBusObserver.any_instance.expects(:after_create_user_action).with(instance_of(UserAction))
    Fabricate(:user_action)
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
        @liker_action = liker.user_actions.where(action_type: UserAction::LIKE).first
        @likee_action = likee.user_actions.where(action_type: UserAction::WAS_LIKED).first
      end

      it 'should result in correct data assignment' do
        @liker_action.should_not be_nil
        @likee_action.should_not be_nil
        likee.reload.likes_received.should == 1
        liker.reload.likes_given.should == 1

        PostAction.remove_act(liker, post, PostActionType.types[:like])
        likee.reload.likes_received.should == 0
        liker.reload.likes_given.should == 0
      end

    end

    context "liking a private message" do

      before do
        post.topic.update_column(:archetype, Archetype::private_message)
      end

      it "doesn't add the entry to the stream" do
        PostAction.act(liker, post, PostActionType.types[:like])
        likee_stream.count.should_not == @old_count + 1
      end

    end

  end

  describe 'when a user posts a new topic' do
    before do
      @post = Fabricate(:old_post)
    end

    describe 'topic action' do
      before do
        @action = @post.user.user_actions.where(action_type: UserAction::NEW_TOPIC).first
      end
      it 'should exist' do
        @action.should_not be_nil
        @action.created_at.should be_within(1).of(@post.topic.created_at)
      end
    end

    it 'should not log a post user action' do
      @post.user.user_actions.where(action_type: UserAction::REPLY).first.should be_nil
    end


    describe 'when another user posts on the topic' do
      before do
        @other_user = Fabricate(:coding_horror)
        @mentioned = Fabricate(:admin)
        @response = Fabricate(:post, reply_to_post_number: 1, topic: @post.topic, user: @other_user, raw: "perhaps @#{@mentioned.username} knows how this works?")
      end

      it 'should log user actions correctly' do
        @response.user.user_actions.where(action_type: UserAction::REPLY).first.should_not be_nil
        @post.user.user_actions.where(action_type: UserAction::RESPONSE).first.should_not be_nil
        @mentioned.user_actions.where(action_type: UserAction::MENTION).first.should_not be_nil
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
      @action = @user.user_actions.where(action_type: UserAction::BOOKMARK).first
    end

    it 'should create a bookmark action correctly' do
      @action.action_type.should == UserAction::BOOKMARK
      @action.target_post_id.should == @post.id
      @action.acting_user_id.should == @user.id
      @action.user_id.should == @user.id

      PostAction.remove_act(@user, @post, PostActionType.types[:bookmark])
      @user.user_actions.where(action_type: UserAction::BOOKMARK).first.should be_nil
    end
  end
end
