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

    describe 'stats' do

      let :mystats do
        UserAction.stats(user.id, Guardian.new(user))
      end

      it 'include correct events' do
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::NEW_TOPIC)
        UserAction.stats(user.id,Guardian.new).map{|r| r["action_type"].to_i}.should_not include(UserAction::NEW_PRIVATE_MESSAGE)
        UserAction.stats(user.id,Guardian.new).map{|r| r["action_type"].to_i}.should_not include(UserAction::GOT_PRIVATE_MESSAGE)
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::NEW_PRIVATE_MESSAGE)
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::GOT_PRIVATE_MESSAGE)
      end

      it 'should not include new topic when topic is deleted' do
        public_topic.destroy
        mystats.map{|r| r["action_type"].to_i}.should_not include(UserAction::NEW_TOPIC)
      end

    end

    describe 'stream' do

      it 'should have 1 item for non owners' do
        UserAction.stream(user_id: user.id, guardian: Guardian.new).count.should == 1
      end

      it 'should include no items for non owner when topic deleted' do
        public_topic.destroy
        UserAction.stream(user_id: user.id, guardian: Guardian.new).count.should == 0
      end

      it 'should have bookmarks and pms for owners' do
        UserAction.stream(user_id: user.id, guardian: user.guardian).count.should == 4
      end

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
      end
      it 'shoule have the correct date' do
        @action.created_at.should be_within(1).of(@post.topic.created_at)
      end
    end

    it 'should not log a post user action' do
      @post.user.user_actions.where(action_type: UserAction::POST).first.should be_nil
    end


    describe 'when another user posts on the topic' do
      before do
        @other_user = Fabricate(:coding_horror)
        @mentioned = Fabricate(:admin)
        @response = Fabricate(:post, reply_to_post_number: 1, topic: @post.topic, user: @other_user, raw: "perhaps @#{@mentioned.username} knows how this works?")
      end

      it 'should log a post action for the poster' do
        @response.user.user_actions.where(action_type: UserAction::POST).first.should_not be_nil
      end

      it 'should log a post action for the original poster' do
        @post.user.user_actions.where(action_type: UserAction::RESPONSE).first.should_not be_nil
      end

      it 'should log a mention for the mentioned' do
        @mentioned.user_actions.where(action_type: UserAction::MENTION).first.should_not be_nil
      end

      it 'should not log a double notification for a post edit' do
        @response.raw = "here it goes again"
        @response.save!
        @response.user.user_actions.where(action_type: UserAction::POST).count.should == 1
      end

      it 'should not log topic reply and reply for a single post' do
        @post.user.user_actions.joins(:target_post).where('posts.post_number = 2').count.should == 1
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

    it 'should create a bookmark action' do
      @action.action_type.should == UserAction::BOOKMARK
    end
    it 'should point to the correct post' do
      @action.target_post_id.should == @post.id
    end
    it 'should have the right acting_user' do
      @action.acting_user_id.should == @user.id
    end
    it 'should target the correct user' do
      @action.user_id.should == @user.id
    end
    it 'should nuke the action when unbookmarked' do
      PostAction.remove_act(@user, @post, PostActionType.types[:bookmark])
      @user.user_actions.where(action_type: UserAction::BOOKMARK).first.should be_nil
    end
  end
end
