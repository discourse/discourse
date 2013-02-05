require 'spec_helper'

describe TopicUser do

  it { should belong_to :user }
  it { should belong_to :topic }

  before do
    #mock time so we can test dates
    @now = DateTime.now.yesterday
    DateTime.expects(:now).at_least_once.returns(@now)
    @topic = Fabricate(:topic)
    @user = Fabricate(:coding_horror)
  end

  describe 'notifications' do 

    it 'should be set to tracking if auto_track_topics is enabled' do 
      @user.auto_track_topics_after_msecs = 0
      @user.save
      TopicUser.change(@user, @topic, {:starred_at => DateTime.now})
      TopicUser.get(@topic,@user).notification_level.should == TopicUser::NotificationLevel::TRACKING
    end

    it 'should reset regular topics to tracking topics if auto track is changed' do 
      TopicUser.change(@user, @topic, {:starred_at => DateTime.now})
      @user.auto_track_topics_after_msecs = 0
      @user.save
      TopicUser.get(@topic,@user).notification_level.should == TopicUser::NotificationLevel::TRACKING
    end

    it 'should be set to "regular" notifications, by default on non creators' do 
      TopicUser.change(@user, @topic, {:starred_at => DateTime.now})
      TopicUser.get(@topic,@user).notification_level.should == TopicUser::NotificationLevel::REGULAR
    end

    it 'reason should reset when changed' do 
      @topic.notify_muted!(@topic.user)
      TopicUser.get(@topic,@topic.user).notifications_reason_id.should == TopicUser::NotificationReasons::USER_CHANGED
    end
    
    it 'should have the correct reason for a user change when watched' do 
      @topic.notify_watch!(@user)
      tu = TopicUser.get(@topic,@user)
      tu.notification_level.should == TopicUser::NotificationLevel::WATCHING
      tu.notifications_reason_id.should == TopicUser::NotificationReasons::USER_CHANGED
      tu.notifications_changed_at.should_not be_nil
    end
    
    it 'should have the correct reason for a user change when set to regular' do 
      @topic.notify_regular!(@user)
      tu = TopicUser.get(@topic,@user)
      tu.notification_level.should == TopicUser::NotificationLevel::REGULAR
      tu.notifications_reason_id.should == TopicUser::NotificationReasons::USER_CHANGED
      tu.notifications_changed_at.should_not be_nil
    end
    
    it 'should have the correct reason for a user change when set to regular' do 
      @topic.notify_muted!(@user)
      tu = TopicUser.get(@topic,@user)
      tu.notification_level.should == TopicUser::NotificationLevel::MUTED
      tu.notifications_reason_id.should == TopicUser::NotificationReasons::USER_CHANGED
      tu.notifications_changed_at.should_not be_nil
    end

    it 'should watch topics a user created' do
      tu = TopicUser.get(@topic,@topic.user)
      tu.notification_level.should == TopicUser::NotificationLevel::WATCHING
      tu.notifications_reason_id.should == TopicUser::NotificationReasons::CREATED_TOPIC
    end
  end

  describe 'visited at' do
    before do
      TopicUser.track_visit!(@topic, @user)
      @topic_user = TopicUser.get(@topic,@user)

    end   
    
    it 'set upon initial visit' do 
      @topic_user.first_visited_at.to_i.should == @now.to_i
      @topic_user.last_visited_at.to_i.should == @now.to_i
    end

    it 'updates upon repeat visit' do 
      tomorrow = @now.tomorrow
      DateTime.expects(:now).returns(tomorrow)
      
      TopicUser.track_visit!(@topic,@user)
      # reload is a no go
      @topic_user = TopicUser.get(@topic,@user)
      @topic_user.first_visited_at.to_i.should == @now.to_i
      @topic_user.last_visited_at.to_i.should == tomorrow.to_i
    end

  end

  describe 'read tracking' do 
    before do 
      @post = Fabricate(:post, topic: @topic, user: @topic.user) 
      TopicUser.update_last_read(@user, @topic.id, 1, 0)
      @topic_user = TopicUser.get(@topic,@user)
    end

    it 'should create a new record for a visit' do 
      @topic_user.last_read_post_number.should == 1
      @topic_user.last_visited_at.to_i.should == @now.to_i
      @topic_user.first_visited_at.to_i.should == @now.to_i
    end
    
    it 'should update the record for repeat visit' do 
      Fabricate(:post, topic: @topic, user: @user) 
      TopicUser.update_last_read(@user, @topic.id, 2, 0)
      @topic_user = TopicUser.get(@topic,@user)
      @topic_user.last_read_post_number.should == 2
      @topic_user.last_visited_at.to_i.should == @now.to_i
      @topic_user.first_visited_at.to_i.should == @now.to_i
    end

    context 'auto tracking' do 
      before do
        Fabricate(:post, topic: @topic, user: @user) 
        @new_user = Fabricate(:user, auto_track_topics_after_msecs: 1000)
        TopicUser.update_last_read(@new_user, @topic.id, 2, 0)
        @topic_user = TopicUser.get(@topic,@new_user)
      end
      
      it 'should automatically track topics you reply to' do
        post = Fabricate(:post, topic: @topic, user: @new_user)
        @topic_user = TopicUser.get(@topic,@new_user)
        @topic_user.notification_level.should == TopicUser::NotificationLevel::TRACKING
        @topic_user.notifications_reason_id.should == TopicUser::NotificationReasons::CREATED_POST
      end
      
      it 'should not automatically track topics you reply to and have set state manually' do
        Fabricate(:post, topic: @topic, user: @new_user)
        TopicUser.change(@new_user, @topic, notification_level: TopicUser::NotificationLevel::REGULAR)
        @topic_user = TopicUser.get(@topic,@new_user)
        @topic_user.notification_level.should == TopicUser::NotificationLevel::REGULAR
        @topic_user.notifications_reason_id.should == TopicUser::NotificationReasons::USER_CHANGED
      end

      it 'should automatically track topics after they are read for long enough' do 
        @topic_user.notification_level.should == TopicUser::NotificationLevel::REGULAR
        TopicUser.update_last_read(@new_user, @topic.id, 2, 1001)
        @topic_user = TopicUser.get(@topic,@new_user)
        @topic_user.notification_level.should == TopicUser::NotificationLevel::TRACKING
      end
      
      it 'should not automatically track topics after they are read for long enough if changed manually' do 
        TopicUser.change(@new_user, @topic, notification_level: TopicUser::NotificationLevel::REGULAR)
        @topic_user = TopicUser.get(@topic,@new_user)

        TopicUser.update_last_read(@new_user, @topic, 2, 1001)
        @topic_user = TopicUser.get(@topic,@new_user)
        @topic_user.notification_level.should == TopicUser::NotificationLevel::REGULAR
      end
    end
  end

  describe 'change a flag' do

    it 'creates a forum topic user record' do
      lambda {
        TopicUser.change(@user, @topic.id, starred: true)
      }.should change(TopicUser, :count).by(1)
    end

    it "only inserts a row once, even on repeated calls" do
      lambda {
        TopicUser.change(@user, @topic.id, starred: true)
        TopicUser.change(@user, @topic.id, starred: false)
        TopicUser.change(@user, @topic.id, starred: true)
      }.should change(TopicUser, :count).by(1)
    end
    
    describe 'after creating a row' do
      before do
        TopicUser.change(@user, @topic.id, starred: true)
        @topic_user = TopicUser.where(user_id: @user.id, topic_id: @topic.id).first
      end

      it 'has the correct starred value' do
        @topic_user.should be_starred
      end

      it 'has a lookup' do
        TopicUser.lookup_for(@user, [@topic]).should be_present
      end

      it 'has a key in the lookup for this forum topic' do
        TopicUser.lookup_for(@user, [@topic]).has_key?(@topic.id).should be_true
      end

    end

  end

end 
