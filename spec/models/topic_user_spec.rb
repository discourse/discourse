require 'spec_helper'

describe TopicUser do

  it { should belong_to :user }
  it { should belong_to :topic }

  let!(:yesterday) { DateTime.now.yesterday }

  before do
    DateTime.expects(:now).at_least_once.returns(yesterday)
  end

  let!(:user) { Fabricate(:coding_horror) }
  let!(:topic) {
    user = Fabricate(:user)
    guardian = Guardian.new(user)
    TopicCreator.create(user, guardian, title: "this is my topic title")
  }
  let(:topic_user) { TopicUser.get(topic,user) }
  let(:topic_creator_user) { TopicUser.get(topic, topic.user) }

  let(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:new_user) { Fabricate(:user, auto_track_topics_after_msecs: 1000) }
  let(:topic_new_user) { TopicUser.get(topic, new_user)}


  describe "unpinned" do

    before do
      TopicUser.change(user, topic, {starred_at: yesterday})
    end

    it "defaults to blank" do
      topic_user.cleared_pinned_at.should be_blank
    end

  end

  describe 'notifications' do

    it 'should be set to tracking if auto_track_topics is enabled' do
      user.update_column(:auto_track_topics_after_msecs, 0)
      TopicUser.change(user, topic, {starred_at: yesterday})
      TopicUser.get(topic, user).notification_level.should == TopicUser.notification_levels[:tracking]
    end

    it 'should reset regular topics to tracking topics if auto track is changed' do
      TopicUser.change(user, topic, {starred_at: yesterday})
      user.auto_track_topics_after_msecs = 0
      user.save
      topic_user.notification_level.should == TopicUser.notification_levels[:tracking]
    end

    it 'should be set to "regular" notifications, by default on non creators' do
      TopicUser.change(user, topic, {starred_at: yesterday})
      TopicUser.get(topic,user).notification_level.should == TopicUser.notification_levels[:regular]
    end

    it 'reason should reset when changed' do
      topic.notify_muted!(topic.user)
      TopicUser.get(topic,topic.user).notifications_reason_id.should == TopicUser.notification_reasons[:user_changed]
    end

    it 'should have the correct reason for a user change when watched' do
      topic.notify_watch!(user)
      topic_user.notification_level.should == TopicUser.notification_levels[:watching]
      topic_user.notifications_reason_id.should == TopicUser.notification_reasons[:user_changed]
      topic_user.notifications_changed_at.should_not be_nil
    end

    it 'should have the correct reason for a user change when set to regular' do
      topic.notify_regular!(user)
      topic_user.notification_level.should == TopicUser.notification_levels[:regular]
      topic_user.notifications_reason_id.should == TopicUser.notification_reasons[:user_changed]
      topic_user.notifications_changed_at.should_not be_nil
    end

    it 'should have the correct reason for a user change when set to regular' do
      topic.notify_muted!(user)
      topic_user.notification_level.should == TopicUser.notification_levels[:muted]
      topic_user.notifications_reason_id.should == TopicUser.notification_reasons[:user_changed]
      topic_user.notifications_changed_at.should_not be_nil
    end

    it 'should watch topics a user created' do
      topic_creator_user.notification_level.should == TopicUser.notification_levels[:watching]
      topic_creator_user.notifications_reason_id.should == TopicUser.notification_reasons[:created_topic]
    end
  end

  describe 'visited at' do

    before do
      TopicUser.track_visit!(topic, user)
    end

    it 'set upon initial visit' do
      topic_user.first_visited_at.to_i.should == yesterday.to_i
      topic_user.last_visited_at.to_i.should == yesterday.to_i
    end

    it 'updates upon repeat visit' do
      today = yesterday.tomorrow
      DateTime.expects(:now).returns(today)

      TopicUser.track_visit!(topic,user)
      # reload is a no go
      topic_user = TopicUser.get(topic,user)
      topic_user.first_visited_at.to_i.should == yesterday.to_i
      topic_user.last_visited_at.to_i.should == today.to_i
    end

    it 'triggers the observer callbacks when updating' do
      UserActionObserver.instance.expects(:after_save).twice
      2.times { TopicUser.track_visit!(topic, user) }
    end
  end

  describe 'read tracking' do

    context "without auto tracking" do

      before do
        TopicUser.update_last_read(user, topic.id, 1, 0)
      end

      let(:topic_user) { TopicUser.get(topic,user) }

      it 'should create a new record for a visit' do
        topic_user.last_read_post_number.should == 1
        topic_user.last_visited_at.to_i.should == yesterday.to_i
        topic_user.first_visited_at.to_i.should == yesterday.to_i
      end

      it 'should update the record for repeat visit' do
        Fabricate(:post, topic: topic, user: user)
        TopicUser.update_last_read(user, topic.id, 2, 0)
        topic_user = TopicUser.get(topic,user)
        topic_user.last_read_post_number.should == 2
        topic_user.last_visited_at.to_i.should == yesterday.to_i
        topic_user.first_visited_at.to_i.should == yesterday.to_i
      end
    end

    context 'auto tracking' do

      let(:post_creator) { PostCreator.new(new_user, raw: Fabricate.build(:post).raw, topic_id: topic.id) }

      before do
        TopicUser.update_last_read(new_user, topic.id, 2, 0)
      end

      it 'should automatically track topics you reply to' do
        post_creator.create
        topic_new_user.notification_level.should == TopicUser.notification_levels[:tracking]
        topic_new_user.notifications_reason_id.should == TopicUser.notification_reasons[:created_post]
      end

      it 'should not automatically track topics you reply to and have set state manually' do
        post_creator.create
        TopicUser.change(new_user, topic, notification_level: TopicUser.notification_levels[:regular])
        topic_new_user.notification_level.should == TopicUser.notification_levels[:regular]
        topic_new_user.notifications_reason_id.should == TopicUser.notification_reasons[:user_changed]
      end

      it 'should automatically track topics after they are read for long enough' do
        topic_new_user.notification_level.should ==TopicUser.notification_levels[:regular]
        TopicUser.update_last_read(new_user, topic.id, 2, 1001)
        TopicUser.get(topic, new_user).notification_level.should == TopicUser.notification_levels[:tracking]
      end

      it 'should not automatically track topics after they are read for long enough if changed manually' do
        TopicUser.change(new_user, topic, notification_level: TopicUser.notification_levels[:regular])
        TopicUser.update_last_read(new_user, topic, 2, 1001)
        topic_new_user.notification_level.should == TopicUser.notification_levels[:regular]
      end
    end
  end

  describe 'change a flag' do

    it 'creates a forum topic user record' do
      lambda {
        TopicUser.change(user, topic.id, starred: true)
      }.should change(TopicUser, :count).by(1)
    end

    it "only inserts a row once, even on repeated calls" do
      lambda {
        TopicUser.change(user, topic.id, starred: true)
        TopicUser.change(user, topic.id, starred: false)
        TopicUser.change(user, topic.id, starred: true)
      }.should change(TopicUser, :count).by(1)
    end

    it 'triggers the observer callbacks when updating' do
      UserActionObserver.instance.expects(:after_save).twice
      3.times { TopicUser.change(user, topic.id, starred: true) }
    end

    describe 'after creating a row' do
      before do
        TopicUser.change(user, topic.id, starred: true)
      end

      it 'has the correct starred value' do
        TopicUser.get(topic, user).should be_starred
      end

      it 'has a lookup' do
        TopicUser.lookup_for(user, [topic]).should be_present
      end

      it 'has a key in the lookup for this forum topic' do
        TopicUser.lookup_for(user, [topic]).has_key?(topic.id).should be_true
      end

    end

  end

  it "can scope by tracking" do
    TopicUser.create!(user_id: 1, topic_id: 1, notification_level: TopicUser.notification_levels[:tracking])
    TopicUser.create!(user_id: 2, topic_id: 1, notification_level: TopicUser.notification_levels[:watching])
    TopicUser.create!(user_id: 3, topic_id: 1, notification_level: TopicUser.notification_levels[:regular])

    TopicUser.tracking(1).count.should == 2
    TopicUser.tracking(10).count.should == 0
  end

  it "is able to self heal" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post, user: p1.user, topic: p1.topic, post_number: 2)
    p1.topic.notifier.watch_topic!(p1.user_id)

    TopicUser.exec_sql("UPDATE topic_users set seen_post_count=100, last_read_post_number=0
                       WHERE topic_id = :topic_id AND user_id = :user_id", topic_id: p1.topic_id, user_id: p1.user_id)

    [p1,p2].each do |p|
      PostTiming.create(topic_id: p.topic_id, post_number: p.post_number, user_id: p.user_id, msecs: 100)
    end

    TopicUser.ensure_consistency!

    tu = TopicUser.where(user_id: p1.user_id, topic_id: p1.topic_id).first
    tu.last_read_post_number.should == p2.post_number
    tu.seen_post_count.should == 2
  end

end
