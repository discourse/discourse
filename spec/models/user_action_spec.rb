require 'spec_helper'

describe UserAction do

  it { should validate_presence_of :action_type }
  it { should validate_presence_of :user_id }


  describe 'lists' do 

    before do 
      a = UserAction.new 
      @post = Fabricate(:post)
      @user = Fabricate(:coding_horror)
      row = { 
        action_type: UserAction::NEW_PRIVATE_MESSAGE,
        user_id: @user.id, 
        acting_user_id: @user.id, 
        target_topic_id: @post.topic_id,
        target_post_id: @post.id, 
      }

      UserAction.log_action!(row)
      
      row[:action_type] = UserAction::GOT_PRIVATE_MESSAGE
      UserAction.log_action!(row)
     
      row[:action_type] = UserAction::NEW_TOPIC
      UserAction.log_action!(row)
        
    end

    describe 'stats' do

      let :mystats do 
        UserAction.stats(@user.id,Guardian.new(@user))
      end

      it 'should include non private message events' do 
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::NEW_TOPIC)
      end

      it 'should exclude private messages for non owners' do 
        UserAction.stats(@user.id,Guardian.new).map{|r| r["action_type"].to_i}.should_not include(UserAction::NEW_PRIVATE_MESSAGE)
      end

      it 'should not include got private messages for owners' do 
        UserAction.stats(@user.id,Guardian.new).map{|r| r["action_type"].to_i}.should_not include(UserAction::GOT_PRIVATE_MESSAGE)
      end
    
      it 'should include private messages for owners' do 
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::NEW_PRIVATE_MESSAGE)
      end

      it 'should include got private messages for owners' do 
        mystats.map{|r| r["action_type"].to_i}.should include(UserAction::GOT_PRIVATE_MESSAGE)
      end
    end

    describe 'stream' do 

      it 'should have 1 item for non owners' do
        UserAction.stream(user_id: @user.id, guardian: Guardian.new).count.should == 1
      end
      
      it 'should have 3 items for non owners' do
        UserAction.stream(user_id: @user.id, guardian: @user.guardian).count.should == 3
      end

    end
  end

  it 'calls the message bus observer' do
    MessageBusObserver.any_instance.expects(:after_create_user_action).with(instance_of(UserAction))
    Fabricate(:user_action)
  end

  describe 'when user likes' do 
    before do 
      @post = Fabricate(:post)
      @likee = @post.user
      @liker = Fabricate(:coding_horror) 
      PostAction.act(@liker, @post, PostActionType.Types[:like])
      @liker_action = @liker.user_actions.where(action_type: UserAction::LIKE).first
      @likee_action = @likee.user_actions.where(action_type: UserAction::WAS_LIKED).first
    end

    it 'should create a like action on the liker' do 
      @liker_action.should_not be_nil 
    end

    it 'should create a like action on the likee' do
      @likee_action.should_not be_nil 
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
      PostAction.act(@user, @post, PostActionType.Types[:bookmark])
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
      PostAction.remove_act(@user, @post, PostActionType.Types[:bookmark])
      @user.user_actions.where(action_type: UserAction::BOOKMARK).first.should be_nil
    end
  end
end
