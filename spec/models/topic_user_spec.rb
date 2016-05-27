require 'rails_helper'

describe TopicUser do

  describe '#notification_levels' do
    context "verify enum sequence" do
      before do
        @notification_levels = TopicUser.notification_levels
      end

      it "'muted' should be at 0 position" do
        expect(@notification_levels[:muted]).to eq(0)
      end

      it "'watching' should be at 3rd position" do
        expect(@notification_levels[:watching]).to eq(3)
      end
    end
  end

  describe '#notification_reasons' do
    context "verify enum sequence" do
      before do
        @notification_reasons = TopicUser.notification_reasons
      end

      it "'created_topic' should be at 1st position" do
        expect(@notification_reasons[:created_topic]).to eq(1)
      end

      it "'plugin_changed' should be at 9th position" do
        expect(@notification_reasons[:plugin_changed]).to eq(9)
      end
    end
  end

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }

  let(:user) { Fabricate(:user) }

  let(:topic) {
    u = Fabricate(:user)
    guardian = Guardian.new(u)
    TopicCreator.create(u, guardian, title: "this is my topic title")
  }
  let(:topic_user) { TopicUser.get(topic,user) }
  let(:topic_creator_user) { TopicUser.get(topic, topic.user) }

  let(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:new_user) {
    u = Fabricate(:user)
    u.user_option.update_columns(auto_track_topics_after_msecs: 1000)
    u
  }

  let(:topic_new_user) { TopicUser.get(topic, new_user)}
  let(:yesterday) { DateTime.now.yesterday }

  def ensure_topic_user
    TopicUser.change(user, topic, last_emailed_post_number: 1)
  end

  describe "unpinned" do

    it "defaults to blank" do
      ensure_topic_user
      expect(topic_user.cleared_pinned_at).to be_blank
    end

  end

  describe 'notifications' do

    it 'should be set to tracking if auto_track_topics is enabled' do
      user.user_option.update_column(:auto_track_topics_after_msecs, 0)
      ensure_topic_user
      expect(TopicUser.get(topic, user).notification_level).to eq(TopicUser.notification_levels[:tracking])
    end

    it 'should reset regular topics to tracking topics if auto track is changed' do
      ensure_topic_user
      user.user_option.auto_track_topics_after_msecs = 0
      user.user_option.save
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:tracking])
    end

    it 'should be set to "regular" notifications, by default on non creators' do
      ensure_topic_user
      expect(TopicUser.get(topic,user).notification_level).to eq(TopicUser.notification_levels[:regular])
    end

    it 'reason should reset when changed' do
      topic.notify_muted!(topic.user)
      expect(TopicUser.get(topic,topic.user).notifications_reason_id).to eq(TopicUser.notification_reasons[:user_changed])
    end

    it 'should have the correct reason for a user change when watched' do
      topic.notify_watch!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:watching])
      expect(topic_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:user_changed])
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it 'should have the correct reason for a user change when set to regular' do
      topic.notify_regular!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:regular])
      expect(topic_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:user_changed])
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it 'should have the correct reason for a user change when set to regular' do
      topic.notify_muted!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:muted])
      expect(topic_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:user_changed])
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it 'should watch topics a user created' do
      expect(topic_creator_user.notification_level).to eq(TopicUser.notification_levels[:watching])
      expect(topic_creator_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:created_topic])
    end
  end

  describe 'visited at' do

    before do
      TopicUser.track_visit!(topic.id, user.id)
    end

    it 'set upon initial visit' do
      freeze_time yesterday do
        expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
        expect(topic_user.last_visited_at.to_i).to eq(yesterday.to_i)
      end
    end

    it 'updates upon repeat visit' do
      today = yesterday.tomorrow

      freeze_time today do
        TopicUser.track_visit!(topic.id, user.id)
        # reload is a no go
        topic_user = TopicUser.get(topic,user)
        expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
        expect(topic_user.last_visited_at.to_i).to eq(today.to_i)
      end
    end

    it 'triggers the observer callbacks when updating' do
      UserActionObserver.instance.expects(:after_save).twice
      2.times { TopicUser.track_visit!(topic.id, user.id) }
    end
  end

  describe 'read tracking' do

    context "without auto tracking" do

      before do
        TopicUser.update_last_read(user, topic.id, 1, 0)
      end

      let(:topic_user) { TopicUser.get(topic,user) }

      it 'should create a new record for a visit' do
        freeze_time yesterday do
          expect(topic_user.last_read_post_number).to eq(1)
          expect(topic_user.last_visited_at.to_i).to eq(yesterday.to_i)
          expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
        end
      end

      it 'should update the record for repeat visit' do
        freeze_time yesterday do
          Fabricate(:post, topic: topic, user: user)
          TopicUser.update_last_read(user, topic.id, 2, 0)
          topic_user = TopicUser.get(topic,user)
          expect(topic_user.last_read_post_number).to eq(2)
          expect(topic_user.last_visited_at.to_i).to eq(yesterday.to_i)
          expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
        end
      end
    end

    context 'private messages' do
      it 'should ensure recepients and senders are watching' do
        ActiveRecord::Base.observers.enable :all

        target_user = Fabricate(:user)
        post = create_post(archetype: Archetype.private_message, target_usernames: target_user.username);

        expect(TopicUser.get(post.topic, post.user).notification_level).to eq(TopicUser.notification_levels[:watching])
        expect(TopicUser.get(post.topic, target_user).notification_level).to eq(TopicUser.notification_levels[:watching])
      end
    end

    context 'auto tracking' do

      let(:post_creator) { PostCreator.new(new_user, raw: Fabricate.build(:post).raw, topic_id: topic.id) }

      before do
        TopicUser.update_last_read(new_user, topic.id, 2, 0)
      end

      it 'should automatically track topics you reply to' do
        post_creator.create
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:tracking])
        expect(topic_new_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:created_post])
      end

      it 'should not automatically track topics you reply to and have set state manually' do
        post_creator.create
        TopicUser.change(new_user, topic, notification_level: TopicUser.notification_levels[:regular])
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
        expect(topic_new_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:user_changed])
      end

      it 'should automatically track topics after they are read for long enough' do
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
        TopicUser.update_last_read(new_user, topic.id, 2, SiteSetting.default_other_auto_track_topics_after_msecs + 1)
        expect(TopicUser.get(topic, new_user).notification_level).to eq(TopicUser.notification_levels[:tracking])
      end

      it 'should not automatically track topics after they are read for long enough if changed manually' do
        TopicUser.change(new_user, topic, notification_level: TopicUser.notification_levels[:regular])
        TopicUser.update_last_read(new_user, topic, 2, SiteSetting.default_other_auto_track_topics_after_msecs + 1)
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
      end
    end
  end

  describe 'change a flag' do

    it "only inserts a row once, even on repeated calls" do

      topic; user

      expect {
        TopicUser.change(user, topic.id, total_msecs_viewed: 1)
        TopicUser.change(user, topic.id, total_msecs_viewed: 2)
        TopicUser.change(user, topic.id, total_msecs_viewed: 3)
      }.to change(TopicUser, :count).by(1)
    end

    describe 'after creating a row' do
      before do
        ensure_topic_user
      end

      it 'has a lookup' do
        expect(TopicUser.lookup_for(user, [topic])).to be_present
      end

      it 'has a key in the lookup for this forum topic' do
        expect(TopicUser.lookup_for(user, [topic]).has_key?(topic.id)).to eq(true)
      end

    end

  end

  it "can scope by tracking" do
    TopicUser.create!(user_id: 1, topic_id: 1, notification_level: TopicUser.notification_levels[:tracking])
    TopicUser.create!(user_id: 2, topic_id: 1, notification_level: TopicUser.notification_levels[:watching])
    TopicUser.create!(user_id: 3, topic_id: 1, notification_level: TopicUser.notification_levels[:regular])

    expect(TopicUser.tracking(1).count).to eq(2)
    expect(TopicUser.tracking(10).count).to eq(0)
  end

  it "is able to self heal" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post, user: p1.user, topic: p1.topic, post_number: 2)
    p1.topic.notifier.watch_topic!(p1.user_id)

    TopicUser.exec_sql("UPDATE topic_users set highest_seen_post_number=1, last_read_post_number=0
                       WHERE topic_id = :topic_id AND user_id = :user_id", topic_id: p1.topic_id, user_id: p1.user_id)

    [p1,p2].each do |p|
      PostTiming.create(topic_id: p.topic_id, post_number: p.post_number, user_id: p.user_id, msecs: 100)
    end

    TopicUser.ensure_consistency!

    tu = TopicUser.find_by(user_id: p1.user_id, topic_id: p1.topic_id)
    expect(tu.last_read_post_number).to eq(p2.post_number)
    expect(tu.highest_seen_post_number).to eq(2)

  end

  describe "mailing_list_mode" do

    it "will receive email notification for every topic" do
      user1 = Fabricate(:user)

      SiteSetting.default_email_mailing_list_mode = true
      SiteSetting.default_email_mailing_list_mode_frequency = 1

      user2 = Fabricate(:user)
      post = create_post

      user3 = Fabricate(:user)
      create_post(topic_id: post.topic_id)

      # mails posts from earlier topics
      tu = TopicUser.find_by(user_id: user3.id, topic_id: post.topic_id)
      expect(tu.last_emailed_post_number).to eq(2)

      # mails nothing to random users
      tu = TopicUser.find_by(user_id: user1.id, topic_id: post.topic_id)
      expect(tu).to eq(nil)

      # mails other user
      tu = TopicUser.find_by(user_id: user2.id, topic_id: post.topic_id)
      expect(tu.last_emailed_post_number).to eq(2)
    end
  end

end
