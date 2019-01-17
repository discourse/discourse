require 'rails_helper'
require_dependency 'post_destroyer'

describe PostAction do
  it { is_expected.to rate_limit }

  let(:moderator) { Fabricate(:moderator) }
  let(:codinghorror) { Fabricate(:coding_horror) }
  let(:eviltrout) { Fabricate(:evil_trout) }
  let(:admin) { Fabricate(:admin) }
  let(:post) { Fabricate(:post) }
  let(:second_post) { Fabricate(:post, topic: post.topic) }
  let(:bookmark) { PostAction.new(user_id: post.user_id, post_action_type_id: PostActionType.types[:bookmark] , post_id: post.id) }

  def value_for(user_id, dt)
    GivenDailyLike.find_for(user_id, dt).pluck(:likes_given)[0] || 0
  end

  describe "rate limits" do

    it "limits redo/undo" do

      RateLimiter.enable

      PostAction.act(eviltrout, post, PostActionType.types[:like])
      PostAction.remove_act(eviltrout, post, PostActionType.types[:like])
      PostAction.act(eviltrout, post, PostActionType.types[:like])
      PostAction.remove_act(eviltrout, post, PostActionType.types[:like])

      expect {
        PostAction.act(eviltrout, post, PostActionType.types[:like])
      }.to raise_error(RateLimiter::LimitExceeded)

    end
  end

  describe "messaging" do

    it "doesn't generate title longer than 255 characters" do
      topic = create_topic(title: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc sit amet rutrum neque. Pellentesque suscipit vehicula facilisis. Phasellus lacus sapien, aliquam nec convallis sit amet, vestibulum laoreet ante. Curabitur et pellentesque tortor. Donec non.")
      post = create_post(topic: topic)
      expect { PostAction.act(admin, post, PostActionType.types[:notify_user], message: "WAT") }.not_to raise_error
    end

    it "notify moderators integration test" do
      post = create_post
      mod = moderator
      Group.refresh_automatic_groups!

      action = PostAction.act(codinghorror, post, PostActionType.types[:notify_moderators], message: "this is my special long message")

      posts = Post.joins(:topic)
        .select('posts.id, topics.subtype, posts.topic_id')
        .where('topics.archetype' => Archetype.private_message)
        .to_a

      expect(posts.count).to eq(1)
      expect(action.related_post_id).to eq(posts[0].id.to_i)
      expect(posts[0].subtype).to eq(TopicSubtype.notify_moderators)

      topic = posts[0].topic

      # Moderators should be invited to the private topic, otherwise they're not permitted to see it
      topic_user_ids = topic.reload.topic_users.map { |x| x.user_id }
      expect(topic_user_ids).to include(codinghorror.id)
      expect(topic_user_ids).to include(mod.id)

      expect(topic.topic_users.where(user_id: mod.id)
              .pluck(:notification_level).first).to eq(TopicUser.notification_levels[:tracking])

      expect(topic.topic_users.where(user_id: codinghorror.id)
              .pluck(:notification_level).first).to eq(TopicUser.notification_levels[:watching])

      # reply to PM should not clear flag
      PostCreator.new(mod, topic_id: posts[0].topic_id, raw: "This is my test reply to the user, it should clear flags").create
      action.reload
      expect(action.deleted_at).to eq(nil)

      # Acting on the flag should not post an automated status message (since a moderator already replied)
      expect(topic.posts.count).to eq(2)
      PostAction.agree_flags!(post, admin)
      expect(action.user.user_stat.flags_agreed).to eq(1)
      expect(action.user.user_stat.flags_disagreed).to eq(0)

      topic.reload
      expect(topic.posts.count).to eq(2)

      # Clearing the flags should not post an automated status message
      new_action = PostAction.act(mod, post, PostActionType.types[:notify_moderators], message: "another special message")
      PostAction.clear_flags!(post, admin)
      expect(new_action.user.user_stat.flags_agreed).to eq(0)
      expect(new_action.user.user_stat.flags_disagreed).to eq(1)
      topic.reload
      expect(topic.posts.count).to eq(2)

      # Acting on the flag should post an automated status message
      another_post = create_post
      action = PostAction.act(codinghorror, another_post, PostActionType.types[:notify_moderators], message: "foobar")
      topic = action.related_post.topic

      expect(topic.posts.count).to eq(1)
      PostAction.agree_flags!(another_post, admin)
      expect(action.user.user_stat.flags_agreed).to eq(2)
      expect(action.user.user_stat.flags_disagreed).to eq(0)

      topic.reload
      expect(topic.posts.count).to eq(2)
      expect(topic.posts.last.post_type).to eq(Post.types[:moderator_action])
    end

    describe 'notify_moderators' do
      before do
        PostAction.stubs(:create)
      end

      it "creates a pm if selected" do
        post = build(:post, id: 1000)
        PostCreator.any_instance.expects(:create).returns(post)
        PostAction.act(build(:user), build(:post), PostActionType.types[:notify_moderators], message: "this is my special message")
      end
    end

    describe "notify_user" do
      before do
        PostAction.stubs(:create)
        post = build(:post)
        post.user = build(:user)
      end

      it "sends an email to user if selected" do
        PostCreator.any_instance.expects(:create).returns(build(:post))
        PostAction.act(build(:user), post, PostActionType.types[:notify_user], message: "this is my special message")
      end
    end
  end

  describe "flag counts" do
    before do
      PostAction.update_flagged_posts_count
    end

    it "increments the numbers correctly" do
      expect(PostAction.flagged_posts_count).to eq(0)

      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      expect(PostAction.flagged_posts_count).to eq(1)

      PostAction.clear_flags!(post, Discourse.system_user)
      expect(PostAction.flagged_posts_count).to eq(0)
    end

    it "respects min_flags_staff_visibility" do
      SiteSetting.min_flags_staff_visibility = 2
      expect(PostAction.flagged_posts_count).to eq(0)

      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      expect(PostAction.flagged_posts_count).to eq(0)

      PostAction.act(eviltrout, post, PostActionType.types[:off_topic])
      expect(PostAction.flagged_posts_count).to eq(1)
    end

    it "tl3 hidden posts will supersede min_flags_staff_visibility" do
      SiteSetting.min_flags_staff_visibility = 2
      expect(PostAction.flagged_posts_count).to eq(0)

      codinghorror.update_column(:trust_level, 3)
      post.user.update_column(:trust_level, 0)
      PostAction.act(codinghorror, post, PostActionType.types[:spam])
      expect(PostAction.flagged_posts_count).to eq(1)
    end

    it "tl4 hidden posts will supersede min_flags_staff_visibility" do
      SiteSetting.min_flags_staff_visibility = 2
      expect(PostAction.flagged_posts_count).to eq(0)

      codinghorror.update_column(:trust_level, 4)
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])

      expect(PostAction.flagged_posts_count).to eq(1)
    end

    it "should reset counts when a topic is deleted" do
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      post.topic.trash!
      expect(PostAction.flagged_posts_count).to eq(0)
    end

    it "should ignore flags on non-human users" do
      post = create_post(user: Discourse.system_user)
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      expect(PostAction.flagged_posts_count).to eq(0)
    end

    it "should ignore validated flags" do
      post = create_post

      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      expect(post.hidden).to eq(false)
      expect(post.hidden_at).to be_blank
      PostAction.defer_flags!(post, admin)
      expect(PostAction.flagged_posts_count).to eq(0)

      post.reload
      expect(post.hidden).to eq(false)
      expect(post.hidden_at).to be_blank

      PostAction.hide_post!(post, PostActionType.types[:off_topic])

      post.reload
      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
    end

  end

  describe "update_counters" do

    it "properly updates topic counters" do
      freeze_time Date.today
      # we need this to test it
      TopicUser.change(codinghorror, post.topic, posted: true)

      expect(value_for(moderator.id, Date.today)).to eq(0)

      PostAction.act(moderator, post, PostActionType.types[:like])
      PostAction.act(codinghorror, second_post, PostActionType.types[:like])

      post.topic.reload
      expect(post.topic.like_count).to eq(2)

      expect(value_for(moderator.id, Date.today)).to eq(1)

      tu = TopicUser.get(post.topic, codinghorror)
      expect(tu.liked).to be true
      expect(tu.bookmarked).to be false
    end

  end

  describe "when a user bookmarks something" do
    it "increases the post's bookmark count when saved" do
      expect { bookmark.save; post.reload }.to change(post, :bookmark_count).by(1)
    end

    describe 'when deleted' do

      before do
        bookmark.save
        post.reload
        @topic = post.topic
        @topic.reload
        bookmark.deleted_at = DateTime.now
        bookmark.save
      end

      it 'reduces the bookmark count of the post' do
        expect { post.reload }.to change(post, :bookmark_count).by(-1)
      end

    end
  end

  describe "undo/redo repeatedly" do
    it "doesn't create a second action for the same user/type" do
      PostAction.act(codinghorror, post, PostActionType.types[:like])
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])
      PostAction.act(codinghorror, post, PostActionType.types[:like])
      expect(PostAction.where(post: post).with_deleted.count).to eq(1)
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])

      # Check that we don't lose consistency into negatives
      expect(post.reload.like_count).to eq(0)
    end
  end

  describe 'when a user likes something' do
    before do
      PostActionNotifier.enable
    end

    it 'should generate and remove notifications correctly' do
      PostAction.act(codinghorror, post, PostActionType.types[:like])

      expect(Notification.count).to eq(1)

      notification = Notification.last

      expect(notification.user_id).to eq(post.user_id)
      expect(notification.notification_type).to eq(Notification.types[:liked])

      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])

      expect(Notification.count).to eq(0)

      PostAction.act(codinghorror, post, PostActionType.types[:like])

      expect(Notification.count).to eq(1)

      notification = Notification.last

      expect(notification.user_id).to eq(post.user_id)
      expect(notification.notification_type).to eq(Notification.types[:liked])
    end

    it 'should not notify when never is selected' do
      post.user.user_option.update!(
        like_notification_frequency:
          UserOption.like_notification_frequency_type[:never]
      )

      expect do
        PostAction.act(codinghorror, post, PostActionType.types[:like])
      end.to_not change { Notification.count }
    end

    it 'notifies on likes correctly' do
      PostAction.act(eviltrout, post, PostActionType.types[:like])
      PostAction.act(admin, post, PostActionType.types[:like])

      # one like
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(1)

      post.user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:always]
      )

      admin2 = Fabricate(:admin)

      # Travel 1 hour in time to test that order post_actions by `created_at`
      freeze_time 1.hour.from_now

      expect do
        PostAction.act(admin2, post, PostActionType.types[:like])
      end.to_not change { Notification.count }

      # adds info to the notification
      notification = Notification.find_by(
        post_number: 1,
        topic_id: post.topic_id
      )

      expect(notification.data_hash["count"].to_i).to eq(2)
      expect(notification.data_hash["username2"]).to eq(eviltrout.username)

      # this is a tricky thing ... removing a like should fix up the notifications
      PostAction.remove_act(eviltrout, post, PostActionType.types[:like])

      # rebuilds the missing notification
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(1)

      notification = Notification.find_by(
        post_number: 1,
        topic_id: post.topic_id
      )

      expect(notification.data_hash["count"]).to eq(2)
      expect(notification.data_hash["username"]).to eq(admin2.username)
      expect(notification.data_hash["username2"]).to eq(admin.username)

      post.user.user_option.update!(
        like_notification_frequency:
        UserOption.like_notification_frequency_type[:first_time_and_daily]
      )

      # this gets skipped
      admin3 = Fabricate(:admin)
      PostAction.act(admin3, post, PostActionType.types[:like])

      freeze_time 2.days.from_now

      admin4 = Fabricate(:admin)
      PostAction.act(admin4, post, PostActionType.types[:like])

      # first happend within the same day, no need to notify
      expect(Notification.where(post_number: 1, topic_id: post.topic_id).count)
        .to eq(2)
    end

    describe 'likes consolidation' do
      let(:liker) { Fabricate(:user) }
      let(:liker2) { Fabricate(:user) }
      let(:likee) { Fabricate(:user) }

      it "can be disabled" do
        SiteSetting.likes_notification_consolidation_threshold = 0

        expect do
          PostAction.act(
            liker,
            Fabricate(:post, user: likee),
            PostActionType.types[:like]
          )
        end.to change { likee.reload.notifications.count }.by(1)

        SiteSetting.likes_notification_consolidation_threshold = 1

        expect do
          PostAction.act(
            liker,
            Fabricate(:post, user: likee),
            PostActionType.types[:like]
          )
        end.to_not change { likee.reload.notifications.count }
      end

      describe 'frequency first_time_and_daily' do
        before do
          likee.user_option.update!(
            like_notification_frequency:
              UserOption.like_notification_frequency_type[:first_time_and_daily]
          )
        end

        it 'should consolidate likes notification when the threshold is reached' do
          SiteSetting.likes_notification_consolidation_threshold = 2

          expect do
            3.times do
              PostAction.act(
                liker,
                Fabricate(:post, user: likee),
                PostActionType.types[:like]
              )
            end
          end.to change { likee.reload.notifications.count }.by(1)

          notification = likee.notifications.last

          expect(notification.notification_type).to eq(
            Notification.types[:liked_consolidated]
          )

          data = JSON.parse(notification.data)

          expect(data["username"]).to eq(liker.username)
          expect(data["display_username"]).to eq(liker.username)
          expect(data["count"]).to eq(3)

          notification.update!(read: true)

          expect do
            2.times do
              PostAction.act(
                liker,
                Fabricate(:post, user: likee),
                PostActionType.types[:like]
              )
            end
          end.to_not change { likee.reload.notifications.count }

          data = JSON.parse(notification.reload.data)

          expect(notification.read).to eq(false)
          expect(data["count"]).to eq(5)

          # Like from a different user shouldn't be consolidated
          expect do
            PostAction.act(
              Fabricate(:user),
              Fabricate(:post, user: likee),
              PostActionType.types[:like]
            )
          end.to change { likee.reload.notifications.count }.by(1)

          notification = likee.notifications.last

          expect(notification.notification_type).to eq(
            Notification.types[:liked]
          )

          freeze_time((
            SiteSetting.likes_notification_consolidation_window_mins.minutes +
            1
          ).since)

          expect do
            PostAction.act(
              liker,
              Fabricate(:post, user: likee),
              PostActionType.types[:like]
            )
          end.to change { likee.reload.notifications.count }.by(1)

          notification = likee.notifications.last

          expect(notification.notification_type).to eq(Notification.types[:liked])
        end
      end

      describe 'frequency always' do
        before do
          likee.user_option.update!(
            like_notification_frequency:
              UserOption.like_notification_frequency_type[:always]
          )
        end

        it 'should consolidate liked notifications when threshold is reached' do
          SiteSetting.likes_notification_consolidation_threshold = 2

          post = Fabricate(:post, user: likee)

          expect do
            [liker2, liker].each do |user|
              PostAction.act(user, post, PostActionType.types[:like])
            end
          end.to change { likee.reload.notifications.count }.by(1)

          notification = likee.notifications.last
          data_hash = notification.data_hash

          expect(data_hash["original_username"]).to eq(liker.username)
          expect(data_hash["username2"]).to eq(liker2.username)
          expect(data_hash["count"].to_i).to eq(2)

          expect do
            2.times do
              PostAction.act(
                liker,
                Fabricate(:post, user: likee),
                PostActionType.types[:like]
              )
            end
          end.to change { likee.reload.notifications.count }.by(2)

          expect(likee.notifications.pluck(:notification_type).uniq)
            .to contain_exactly(Notification.types[:liked])

          expect do
            PostAction.act(
              liker,
              Fabricate(:post, user: likee),
              PostActionType.types[:like]
            )
          end.to change { likee.reload.notifications.count }.by(-1)

          notification = likee.notifications.last

          expect(notification.notification_type).to eq(
            Notification.types[:liked_consolidated]
          )

          expect(notification.data_hash["count"].to_i).to eq(3)
          expect(notification.data_hash["username"]).to eq(liker.username)
        end
      end
    end

    it "should not generate a notification if liker has been muted" do
      mutee = Fabricate(:user)
      MutedUser.create!(user_id: post.user.id, muted_user_id: mutee.id)

      expect do
        PostAction.act(mutee, post, PostActionType.types[:like])
      end.to_not change { Notification.count }
    end

    it 'should not generate a notification if liker has the topic muted' do
      post = Fabricate(:post, user: eviltrout)

      TopicUser.create!(
        topic: post.topic,
        user: eviltrout,
        notification_level: TopicUser.notification_levels[:muted]
      )

      expect do
        PostAction.act(codinghorror, post, PostActionType.types[:like])
      end.to_not change { Notification.count }
    end

    it "should generate a notification if liker is an admin irregardles of \
      muting" do

      MutedUser.create!(user_id: post.user.id, muted_user_id: admin.id)

      expect do
        PostAction.act(admin, post, PostActionType.types[:like])
      end.to change { Notification.count }.by(1)

      notification = Notification.last

      expect(notification.user_id).to eq(post.user_id)
      expect(notification.notification_type).to eq(Notification.types[:liked])
    end

    it 'should increase the `like_count` and `like_score` when a user likes something' do
      freeze_time Date.today

      PostAction.act(codinghorror, post, PostActionType.types[:like])
      post.reload
      expect(post.like_count).to eq(1)
      expect(post.like_score).to eq(1)
      post.topic.reload
      expect(post.topic.like_count).to eq(1)
      expect(value_for(codinghorror.id, Date.today)).to eq(1)

      # When a staff member likes it
      PostAction.act(moderator, post, PostActionType.types[:like])
      post.reload
      expect(post.like_count).to eq(2)
      expect(post.like_score).to eq(4)
      expect(post.topic.like_count).to eq(2)

      # Removing likes
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])
      post.reload
      expect(post.like_count).to eq(1)
      expect(post.like_score).to eq(3)
      expect(post.topic.like_count).to eq(1)
      expect(value_for(codinghorror.id, Date.today)).to eq(0)

      PostAction.remove_act(moderator, post, PostActionType.types[:like])
      post.reload
      expect(post.like_count).to eq(0)
      expect(post.like_score).to eq(0)
      expect(post.topic.like_count).to eq(0)
    end

    it "shouldn't change given_likes unless likes are given or removed" do
      freeze_time(Time.zone.now)

      PostAction.act(codinghorror, Fabricate(:post), PostActionType.types[:like])
      expect(value_for(codinghorror.id, Date.today)).to eq(1)

      PostActionType.types.each do |type_name, type_id|
        post = Fabricate(:post)

        PostAction.act(codinghorror, post, type_id)
        actual_count = value_for(codinghorror.id, Date.today)
        expected_count = type_name == :like ? 2 : 1
        expect(actual_count).to eq(expected_count), "Expected likes_given to be #{expected_count} when adding '#{type_name}', but got #{actual_count}"

        PostAction.remove_act(codinghorror, post, type_id)
        actual_count = value_for(codinghorror.id, Date.today)
        expect(actual_count).to eq(1), "Expected likes_given to be 1 when removing '#{type_name}', but got #{actual_count}"
      end
    end
  end

  describe 'flagging' do

    context "flag_counts_for" do
      it "returns the correct flag counts" do
        post = create_post

        SiteSetting.flags_required_to_hide_post = 7

        # A post with no flags has 0 for flag counts
        expect(PostAction.flag_counts_for(post.id)).to eq([0, 0])

        _flag = PostAction.act(eviltrout, post, PostActionType.types[:spam])
        expect(PostAction.flag_counts_for(post.id)).to eq([0, 1])

        # If staff takes action, it is ranked higher
        PostAction.act(admin, post, PostActionType.types[:spam], take_action: true)
        expect(PostAction.flag_counts_for(post.id)).to eq([0, 8])

        # If a flag is dismissed
        PostAction.clear_flags!(post, admin)
        expect(PostAction.flag_counts_for(post.id)).to eq([0, 8])
      end
    end

    it 'does not allow you to flag stuff with the same reason more than once' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      expect { PostAction.act(eviltrout, post, PostActionType.types[:off_topic]) }.to raise_error(PostAction::AlreadyActed)
    end

    it 'allows you to flag stuff with another reason' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.remove_act(eviltrout, post, PostActionType.types[:spam])
      expect { PostAction.act(eviltrout, post, PostActionType.types[:off_topic]) }.not_to raise_error()
    end

    it 'should update counts when you clear flags' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])

      post.reload
      expect(post.spam_count).to eq(1)

      PostAction.clear_flags!(post, Discourse.system_user)

      post.reload
      expect(post.spam_count).to eq(0)
    end

    it "will not allow regular users to auto hide staff posts" do
      mod = Fabricate(:moderator)
      post = Fabricate(:post, user: mod)

      SiteSetting.flags_required_to_hide_post = 2
      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(Fabricate(:walter_white), post, PostActionType.types[:spam])

      post.reload

      expect(post.hidden).to eq(false)
      expect(post.hidden_at).to be_blank
    end

    it "allows staff users to auto hide staff posts" do
      mod = Fabricate(:moderator)
      post = Fabricate(:post, user: mod)

      SiteSetting.flags_required_to_hide_post = 2
      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(Fabricate(:admin), post, PostActionType.types[:spam])

      post.reload

      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
    end

    it 'should follow the rules for automatic hiding workflow' do
      post = create_post
      walterwhite = Fabricate(:walter_white)

      SiteSetting.flags_required_to_hide_post = 2
      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(walterwhite, post, PostActionType.types[:spam])

      job_args = Jobs::SendSystemMessage.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(post.user.id)
      expect(job_args["message_type"]).to eq("post_hidden")

      post.reload

      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flag_threshold_reached])
      expect(post.topic.visible).to eq(false)

      post.revise(post.user, raw: post.raw + " ha I edited it ")

      post.reload

      expect(post.hidden).to eq(false)
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flag_threshold_reached]) # keep most recent reason
      expect(post.hidden_at).to be_present # keep the most recent hidden_at time
      expect(post.topic.visible).to eq(true)

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(walterwhite, post, PostActionType.types[:off_topic])

      job_args = Jobs::SendSystemMessage.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(post.user.id)
      expect(job_args["message_type"]).to eq("post_hidden_again")

      post.reload

      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flag_threshold_reached_again])
      expect(post.topic.visible).to eq(false)

      post.revise(post.user, raw: post.raw + " ha I edited it again ")

      post.reload

      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flag_threshold_reached_again])
      expect(post.topic.visible).to eq(false)
    end

    it "doesn't fail when post has nil user" do
      post = create_post
      post.update!(user: nil)

      PostAction.act(codinghorror, post, PostActionType.types[:spam], take_action: true)
      post.reload
      expect(post.hidden).to eq(true)
    end

    it "hide tl0 posts that are flagged as spam by a tl3 user" do
      newuser = Fabricate(:newuser)
      post = create_post(user: newuser)

      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(Fabricate(:leader), post, PostActionType.types[:spam])

      post.reload

      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flagged_by_tl3_user])
    end

    it "hide non-tl4 posts that are flagged by a tl4 user" do
      SiteSetting.site_contact_username = admin.username

      post_action_type = PostActionType.types[:spam]
      tl4_user = Fabricate(:trust_level_4)

      user = Fabricate(:leader)
      post = create_post(user: user)

      PostAction.act(tl4_user, post, post_action_type)

      post.reload

      expect(post.hidden).to be_truthy
      expect(post.hidden_at).to be_present
      expect(post.hidden_reason_id).to eq(Post.hidden_reasons[:flagged_by_tl4_user])

      post = create_post(user: user)
      PostAction.act(Fabricate(:leader), post, post_action_type)
      post.reload

      expect(post.hidden).to be_falsey

      post = create_post(user: user)
      PostAction.act(Fabricate(:moderator), post, post_action_type)
      post.reload

      expect(post.hidden).to be_falsey

      user = Fabricate(:trust_level_4)
      post = create_post(user: user)
      PostAction.act(tl4_user, post, post_action_type)
      post.reload

      expect(post.hidden).to be_falsey
    end

    it "can flag the topic instead of a post" do
      post1 = create_post
      _post2 = create_post(topic: post1.topic)
      post_action = PostAction.act(Fabricate(:user), post1, PostActionType.types[:spam], flag_topic: true)
      expect(post_action.targets_topic).to eq(true)
    end

    it "will flag the first post if you flag a topic but there is only one post in the topic" do
      post = create_post
      post_action = PostAction.act(Fabricate(:user), post, PostActionType.types[:spam], flag_topic: true)
      expect(post_action.targets_topic).to eq(false)
      expect(post_action.post_id).to eq(post.id)
    end

    it "will unhide the post when a moderator undos the flag on which s/he took action" do
      Discourse.stubs(:site_contact_user).returns(admin)

      post = create_post
      PostAction.act(moderator, post, PostActionType.types[:spam], take_action: true)

      post.reload
      expect(post.hidden).to eq(true)

      PostAction.remove_act(moderator, post, PostActionType.types[:spam])

      post.reload
      expect(post.hidden).to eq(false)
    end

    context "topic auto closing" do
      let(:topic) { Fabricate(:topic) }
      let(:post1) { create_post(topic: topic) }
      let(:post2) { create_post(topic: topic) }
      let(:post3) { create_post(topic: topic) }

      let(:flagger1) { Fabricate(:user) }
      let(:flagger2) { Fabricate(:user) }

      before do
        SiteSetting.flags_required_to_hide_post = 0
        SiteSetting.num_flags_to_close_topic = 3
        SiteSetting.num_flaggers_to_close_topic = 2
        SiteSetting.num_hours_to_close_topic = 1
      end

      it "will automatically pause a topic due to large community flagging" do
        # reaching `num_flaggers_to_close_topic` isn't enough
        [flagger1, flagger2].each do |flagger|
          PostAction.act(flagger, post1, PostActionType.types[:inappropriate])
        end

        expect(topic.reload.closed).to eq(false)

        # clean up
        PostAction.where(post: post1).delete_all

        # reaching `num_flags_to_close_topic` isn't enough
        [post1, post2, post3].each do |post|
          PostAction.act(flagger1, post, PostActionType.types[:inappropriate])
        end

        expect(topic.reload.closed).to eq(false)

        # clean up
        PostAction.where(post: [post1, post2, post3]).delete_all

        # reaching both should close the topic
        [flagger1, flagger2].each do |flagger|
          [post1, post2, post3].each do |post|
            PostAction.act(flagger, post, PostActionType.types[:inappropriate])
          end
        end

        expect(topic.reload.closed).to eq(true)

        topic_status_update = TopicTimer.last

        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to be_within(1.second).of(1.hour.from_now)
        expect(topic_status_update.status_type).to eq(TopicTimer.types[:open])
      end

      it "will keep the topic in closed status until the community flags are handled" do
        freeze_time

        PostAction.stubs(:auto_close_threshold_reached?).returns(true)
        PostAction.auto_close_if_threshold_reached(topic)

        expect(topic.reload.closed).to eq(true)

        timer = TopicTimer.last
        expect(timer.execute_at).to eq(1.hour.from_now)

        freeze_time timer.execute_at
        Jobs.expects(:enqueue_in).with(1.hour.to_i, :toggle_topic_closed, topic_timer_id: timer.id, state: false).returns(true)
        Jobs::ToggleTopicClosed.new.execute(topic_timer_id: timer.id, state: false)

        expect(topic.reload.closed).to eq(true)
        expect(timer.reload.execute_at).to eq(1.hour.from_now)

        freeze_time timer.execute_at
        PostAction.stubs(:auto_close_threshold_reached?).returns(false)
        Jobs::ToggleTopicClosed.new.execute(topic_timer_id: timer.id, state: false)

        expect(topic.reload.closed).to eq(false)
      end

      it "will reopen topic after the flags are auto handled" do
        freeze_time
        [flagger1, flagger2].each do |flagger|
          [post1, post2, post3].each do |post|
            PostAction.act(flagger, post, PostActionType.types[:inappropriate])
          end
        end

        expect(topic.reload.closed).to eq(true)

        freeze_time 61.days.from_now
        Jobs::AutoQueueHandler.new.execute({})
        Jobs::ToggleTopicClosed.new.execute(topic_timer_id: TopicTimer.last.id, state: false)

        expect(topic.reload.closed).to eq(false)
      end
    end

  end

  it "prevents user to act twice at the same time" do
    # flags are already being tested
    all_types_except_flags = PostActionType.types.except(PostActionType.flag_types_without_custom)
    all_types_except_flags.values.each do |action|
      expect do
        PostAction.act(eviltrout, post, action)
        PostAction.act(eviltrout, post, action)
      end.to raise_error(PostAction::AlreadyActed)
    end
  end

  describe ".create_message_for_post_action" do
    it "does not create a message when there is no message" do
      message_id = PostAction.create_message_for_post_action(Discourse.system_user, post, PostActionType.types[:spam], {})
      expect(message_id).to be_nil
    end

    [:notify_moderators, :notify_user, :spam].each do |post_action_type|
      it "creates a message for #{post_action_type}" do
        message_id = PostAction.create_message_for_post_action(Discourse.system_user, post, PostActionType.types[post_action_type], message: "WAT")
        expect(message_id).to be_present
      end
    end

    it "should raise the right errors when it fails to create a post" do
      begin
        group = Group[:moderators]
        messageable_level = group.messageable_level
        group.update!(messageable_level: Group::ALIAS_LEVELS[:nobody])

        expect do
          PostAction.create_message_for_post_action(
            Fabricate(:user),
            post,
            PostActionType.types[:notify_moderators],
            message: 'testing',
          )
        end.to raise_error(ActiveRecord::RecordNotSaved)
      ensure
        group.update!(messageable_level: messageable_level)
      end
    end

    it "should succeed even with low max title length" do
      SiteSetting.max_topic_title_length = 50
      post.topic.title = 'This is a test topic ' * 2
      post.topic.save!
      message_id = PostAction.create_message_for_post_action(Discourse.system_user, post, PostActionType.types[:notify_moderators], message: "WAT")
      expect(message_id).to be_present
    end
  end

  describe ".lookup_for" do
    it "returns the correct map" do
      user = Fabricate(:user)
      post = Fabricate(:post)
      post_action = PostAction.create(user_id: user.id, post_id: post.id, post_action_type_id: 1)

      map = PostAction.lookup_for(user, [post.topic], post_action.post_action_type_id)

      expect(map).to eq(post.topic_id => [post.post_number])
    end
  end

  describe "#add_moderator_post_if_needed" do

    it "should not add a moderator post when it's disabled" do
      post = create_post

      action = PostAction.act(moderator, post, PostActionType.types[:spam], message: "WAT")
      action.reload
      topic = action.related_post.topic
      expect(topic.posts.count).to eq(1)

      SiteSetting.auto_respond_to_flag_actions = false
      PostAction.agree_flags!(post, admin)
      expect(action.user.user_stat.flags_agreed).to eq(1)

      topic.reload
      expect(topic.posts.count).to eq(1)
    end

    it "should create a notification in the related topic" do
      SiteSetting.queue_jobs = false
      post = Fabricate(:post)
      user = Fabricate(:user)
      action = PostAction.act(user, post, PostActionType.types[:spam], message: "WAT")
      topic = action.reload.related_post.topic
      expect(user.notifications.count).to eq(0)

      SiteSetting.auto_respond_to_flag_actions = true
      PostAction.agree_flags!(post, admin)
      expect(action.user.user_stat.flags_agreed).to eq(1)

      user_notifications = user.notifications
      expect(user_notifications.count).to eq(1)
      expect(user_notifications.last.topic).to eq(topic)
    end

    it "should not add a moderator post when post is flagged via private message" do
      SiteSetting.queue_jobs = false
      post = Fabricate(:post)
      user = Fabricate(:user)
      action = PostAction.act(user, post, PostActionType.types[:notify_user], message: "WAT")
      action.reload.related_post.topic
      expect(user.notifications.count).to eq(0)

      SiteSetting.auto_respond_to_flag_actions = true
      PostAction.agree_flags!(post, admin)
      expect(action.user.user_stat.flags_agreed).to eq(0)

      user_notifications = user.notifications
      expect(user_notifications.count).to eq(0)
    end
  end

  describe "rate limiting" do

    def limiter(tl)
      user = Fabricate.build(:user)
      user.trust_level = tl
      action = PostAction.new(user: user, post_action_type_id: PostActionType.types[:like])
      action.post_action_rate_limiter
    end

    it "should scale up like limits depending on liker" do
      expect(limiter(0).max).to eq SiteSetting.max_likes_per_day
      expect(limiter(1).max).to eq SiteSetting.max_likes_per_day
      expect(limiter(2).max).to eq (SiteSetting.max_likes_per_day * SiteSetting.tl2_additional_likes_per_day_multiplier).to_i
      expect(limiter(3).max).to eq (SiteSetting.max_likes_per_day * SiteSetting.tl3_additional_likes_per_day_multiplier).to_i
      expect(limiter(4).max).to eq (SiteSetting.max_likes_per_day * SiteSetting.tl4_additional_likes_per_day_multiplier).to_i

      SiteSetting.tl2_additional_likes_per_day_multiplier = -1
      expect(limiter(2).max).to eq SiteSetting.max_likes_per_day

      SiteSetting.tl2_additional_likes_per_day_multiplier = 0.8
      expect(limiter(2).max).to eq SiteSetting.max_likes_per_day

      SiteSetting.tl2_additional_likes_per_day_multiplier = "bob"
      expect(limiter(2).max).to eq SiteSetting.max_likes_per_day
    end

  end

  describe '#is_flag?' do
    describe 'when post action is a flag' do
      it 'should return true' do
        PostActionType.notify_flag_types.each do |_type, id|
          post_action = PostAction.new(
            user: codinghorror,
            post_action_type_id: id
          )

          expect(post_action.is_flag?).to eq(true)
        end
      end
    end

    describe 'when post action is not a flag' do
      it 'should return false' do
        post_action = PostAction.new(
          user: codinghorror,
          post_action_type_id: 99
        )

        expect(post_action.is_flag?).to eq(false)
      end
    end
  end

  describe "triggers Discourse events" do
    let(:post) { Fabricate(:post) }

    it 'flag created' do
      event = DiscourseEvent.track_events { PostAction.act(eviltrout, post, PostActionType.types[:spam]) }.last
      expect(event[:event_name]).to eq(:flag_created)
    end

    context "resolving flags" do
      before do
        @flag = PostAction.act(eviltrout, post, PostActionType.types[:spam])
      end

      it 'flag agreed' do
        events = DiscourseEvent.track_events { PostAction.agree_flags!(post, moderator) }.last(2)
        expect(events[0][:event_name]).to eq(:flag_reviewed)
        expect(events[1][:event_name]).to eq(:flag_agreed)
        expect(events[1][:params].first).to eq(@flag)
      end

      it 'flag disagreed' do
        events = DiscourseEvent.track_events { PostAction.clear_flags!(post, moderator) }.last(2)
        expect(events[0][:event_name]).to eq(:flag_reviewed)
        expect(events[1][:event_name]).to eq(:flag_disagreed)
        expect(events[1][:params].first).to eq(@flag)
      end

      it 'flag deferred' do
        events = DiscourseEvent.track_events { PostAction.defer_flags!(post, moderator) }.last(2)
        expect(events[0][:event_name]).to eq(:flag_reviewed)
        expect(events[1][:event_name]).to eq(:flag_deferred)
        expect(events[1][:params].first).to eq(@flag)
      end
    end
  end
end
