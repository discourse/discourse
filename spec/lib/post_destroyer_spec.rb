# frozen_string_literal: true

RSpec.describe PostDestroyer do
  before { UserActionManager.enable }

  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }
  let(:post) { create_post }

  describe "destroy_old_hidden_posts" do
    it "destroys posts that have been hidden for 30 days" do
      now = Time.now

      freeze_time(now - 60.days)
      topic = post.topic
      reply1 = create_post(topic: topic)

      freeze_time(now - 40.days)
      reply2 = create_post(topic: topic)
      reply2.hide!(PostActionType.types[:off_topic])

      freeze_time(now - 20.days)
      reply3 = create_post(topic: topic)
      reply3.hide!(PostActionType.types[:off_topic])

      freeze_time(now - 10.days)
      reply4 = create_post(topic: topic)

      freeze_time(now)
      PostDestroyer.destroy_old_hidden_posts

      reply1.reload
      reply2.reload
      reply3.reload
      reply4.reload

      expect(reply1.deleted_at).to eq(nil)
      expect(reply2.deleted_at).not_to eq(nil)
      expect(reply3.deleted_at).to eq(nil)
      expect(reply4.deleted_at).to eq(nil)
    end
  end

  describe "destroy_old_stubs" do
    it "destroys stubs for deleted by user topics" do
      SiteSetting.delete_removed_posts_after = 24

      PostDestroyer.new(post.user, post).destroy
      post.update_column(:updated_at, 2.days.ago)

      PostDestroyer.destroy_stubs
      expect(post.reload.deleted_at).not_to eq(nil)
    end

    it "destroys stubs for deleted by user posts" do
      SiteSetting.delete_removed_posts_after = 24
      topic = post.topic
      reply1 = create_post(topic: topic)
      reply2 = create_post(topic: topic)
      reply3 = create_post(topic: topic)

      PostDestroyer.new(reply1.user, reply1).destroy
      PostDestroyer.new(reply2.user, reply2).destroy

      reply2.update_column(:updated_at, 2.days.ago)

      PostDestroyer.destroy_stubs

      reply1.reload
      reply2.reload
      reply3.reload

      expect(reply1.deleted_at).to eq(nil)
      expect(reply2.deleted_at).not_to eq(nil)
      expect(reply3.deleted_at).to eq(nil)

      # if topic is deleted we should still be able to destroy stubs

      topic.trash!
      reply1.update_column(:updated_at, 2.days.ago)
      PostDestroyer.destroy_stubs

      reply1.reload
      expect(reply1.deleted_at).to eq(nil)

      # flag the post, it should not nuke the stub anymore
      topic.recover!
      reviewable = PostActionCreator.spam(coding_horror, reply1).reviewable

      PostDestroyer.destroy_stubs

      reply1.reload
      expect(reply1.deleted_at).to eq(nil)

      # ignore the flag, we should be able to delete the stub
      reviewable.perform(Discourse.system_user, :ignore_and_do_nothing)
      PostDestroyer.destroy_stubs

      reply1.reload
      expect(reply1.deleted_at).to_not eq(nil)
    end

    it "uses the delete_removed_posts_after site setting" do
      topic = post.topic
      reply1 = create_post(topic: topic)
      reply2 = create_post(topic: topic)

      PostDestroyer.new(reply1.user, reply1).destroy
      PostDestroyer.new(reply2.user, reply2).destroy

      SiteSetting.delete_removed_posts_after = 1

      reply2.update_column(:updated_at, 70.minutes.ago)

      PostDestroyer.destroy_stubs

      reply1.reload
      reply2.reload

      expect(reply1.deleted_at).to eq(nil)
      expect(reply2.deleted_at).not_to eq(nil)

      SiteSetting.delete_removed_posts_after = 72

      reply1.update_column(:updated_at, 2.days.ago)

      PostDestroyer.destroy_stubs

      expect(reply1.reload.deleted_at).to eq(nil)

      SiteSetting.delete_removed_posts_after = 47

      PostDestroyer.destroy_stubs

      expect(reply1.reload.deleted_at).not_to eq(nil)
    end

    it "deletes posts immediately if delete_removed_posts_after is 0" do
      topic = post.topic
      reply1 = create_post(topic: topic)

      SiteSetting.delete_removed_posts_after = 0

      PostDestroyer.new(reply1.user, reply1).destroy

      expect(reply1.reload.deleted_at).not_to eq(nil)
    end
  end

  describe "recovery and user actions" do
    it "recreates user actions" do
      reply = create_post(topic: post.topic)
      author = reply.user

      post_action =
        author.user_actions.where(action_type: UserAction::REPLY, target_post_id: reply.id).first
      expect(post_action).to be_present

      PostDestroyer.new(moderator, reply).destroy

      # User Action is removed
      post_action =
        author.user_actions.where(action_type: UserAction::REPLY, target_post_id: reply.id).first
      expect(post_action).to be_blank

      PostDestroyer.new(moderator, reply).recover

      # On recovery, the user action is recreated
      post_action =
        author.user_actions.where(action_type: UserAction::REPLY, target_post_id: reply.id).first
      expect(post_action).to be_present
    end

    it "works with topics and posts with no user" do
      post = Fabricate(:post)
      UserDestroyer.new(Discourse.system_user).destroy(post.user, delete_posts: true)

      expect { PostDestroyer.new(admin, post.reload).recover }.to change { post.reload.user_id }.to(
        Discourse.system_user.id,
      ).and change { post.topic.user_id }.to(Discourse.system_user.id)
    end

    it "bypassed validation when updating users" do
      post = create_post

      # ensure user would fail validations
      UserEmail.where(user_id: post.user_id).delete_all

      PostDestroyer.new(admin, post.reload).destroy
      PostDestroyer.new(admin, post.reload, force_destroy: true).destroy

      expect(Post.with_deleted.find_by(id: post.id)).to eq(nil)
    end

    describe "post_count recovery" do
      before do
        post
        @user = post.user
        @reply = create_post(topic: post.topic, user: @user)
        expect(@user.user_stat.post_count).to eq(1)
      end

      it "Recovers the post correctly" do
        PostDestroyer.new(admin, post).destroy

        post.reload
        PostDestroyer.new(admin, post).recover
        recovered_topic = post.reload.topic

        expect(recovered_topic.deleted_at).to be_nil
        expect(recovered_topic.deleted_by_id).to be_nil
      end

      context "with recover" do
        it "doesn't raise an error when the raw doesn't change" do
          PostRevisor.new(@reply).revise!(
            @user,
            { edit_reason: "made a change" },
            force_new_version: true,
          )
          PostDestroyer.new(@user, @reply.reload).recover
        end

        it "won't recover a non user-deleted post" do
          PostRevisor.new(@reply).revise!(
            admin,
            { raw: "this is a change to the post" },
            force_new_version: true,
          )
          PostDestroyer.new(@user, @reply.reload).recover
          expect(@reply.reload.raw).to eq("this is a change to the post")
        end

        it "should increment the user's post count" do
          PostDestroyer.new(@user, @reply).destroy
          expect(@user.user_stat.topic_count).to eq(1)
          expect(@user.user_stat.post_count).to eq(1)

          PostDestroyer.new(@user, @reply.reload).recover
          expect(@user.user_stat.topic_count).to eq(1)
          expect(@user.reload.user_stat.post_count).to eq(1)

          expect(
            UserAction.where(
              target_topic_id: post.topic_id,
              action_type: UserAction::NEW_TOPIC,
            ).count,
          ).to eq(1)
          expect(
            UserAction.where(target_topic_id: post.topic_id, action_type: UserAction::REPLY).count,
          ).to eq(1)
        end

        it "runs the SyncTopicUserBookmarked for the topic that the post is in so topic_users.bookmarked is correct" do
          PostDestroyer.new(@user, @reply).destroy
          expect_enqueued_with(
            job: :sync_topic_user_bookmarked,
            args: {
              topic_id: @reply.topic_id,
            },
          ) { PostDestroyer.new(@user, @reply.reload).recover }
        end
      end

      context "when recovered by admin" do
        it "should set user_deleted to false" do
          PostDestroyer.new(@user, @reply).destroy
          expect(@reply.reload.user_deleted).to eq(true)

          PostDestroyer.new(admin, @reply).recover
          expect(@reply.reload.user_deleted).to eq(false)
        end

        it "should increment the user's post count" do
          PostDestroyer.new(moderator, @reply).destroy
          expect(@user.reload.user_stat.topic_count).to eq(1)
          expect(@user.user_stat.post_count).to eq(0)

          PostDestroyer.new(admin, @reply).recover
          expect(@user.reload.user_stat.topic_count).to eq(1)
          expect(@user.user_stat.post_count).to eq(1)

          PostDestroyer.new(moderator, post).destroy
          expect(@user.reload.user_stat.topic_count).to eq(0)
          expect(@user.user_stat.post_count).to eq(0)

          PostDestroyer.new(admin, post).recover
          expect(@user.reload.user_stat.topic_count).to eq(1)
          expect(@user.user_stat.post_count).to eq(1)

          expect(
            UserAction.where(
              target_topic_id: post.topic_id,
              action_type: UserAction::NEW_TOPIC,
            ).count,
          ).to eq(1)
          expect(
            UserAction.where(target_topic_id: post.topic_id, action_type: UserAction::REPLY).count,
          ).to eq(1)
        end

        context "when recovered by user with access to moderate topic category" do
          fab!(:review_user) { Fabricate(:user) }

          before do
            SiteSetting.enable_category_group_moderation = true
            review_group = Fabricate(:group)
            review_category = Fabricate(:category)
            Fabricate(:category_moderation_group, category: review_category, group: review_group)
            @reply.topic.update!(category: review_category)
            review_group.users << review_user
          end

          context "when the post has a Reviewable record" do
            before do
              ReviewableFlaggedPost.needs_review!(target: @reply, created_by: Fabricate(:user))
            end

            def changes_deleted_at_to_nil
              PostDestroyer.new(Discourse.system_user, @reply).destroy
              @reply.reload
              expect(@reply.user_deleted).to eq(false)
              expect(@reply.deleted_at).not_to eq(nil)

              PostDestroyer.new(review_user, @reply).recover
              @reply.reload
              expect(@reply.deleted_at).to eq(nil)
            end

            it "changes deleted_at to nil" do
              changes_deleted_at_to_nil
            end

            context "when the topic is deleted" do
              before { @reply.topic.trash! }
              it "changes deleted_at to nil" do
                changes_deleted_at_to_nil
              end
            end
          end
        end
      end
    end
  end

  describe "recovery and post actions" do
    fab!(:codinghorror) { coding_horror }
    let!(:like) { PostActionCreator.like(codinghorror, post).post_action }
    let!(:another_like) { PostActionCreator.like(moderator, post).post_action }

    it "restores public post actions" do
      PostDestroyer.new(moderator, post).destroy
      expect(PostAction.exists?(id: like.id)).to eq(false)

      PostDestroyer.new(moderator, post).recover
      expect(PostAction.exists?(id: like.id)).to eq(true)
    end

    it "does not recover previously-deleted actions" do
      PostActionDestroyer.destroy(codinghorror, post, :like)
      expect(PostAction.exists?(id: like.id)).to eq(false)

      PostDestroyer.new(moderator, post).destroy
      PostDestroyer.new(moderator, post).recover
      expect(PostAction.exists?(id: another_like.id)).to eq(true)
      expect(PostAction.exists?(id: like.id)).to eq(false)
    end

    it "updates post like count" do
      PostDestroyer.new(moderator, post).destroy
      PostDestroyer.new(moderator, post).recover
      post.reload
      expect(post.like_count).to eq(2)
      expect(post.custom_fields["deleted_public_actions"]).to be_nil
    end

    it "unmarks the matching incoming email for imap sync" do
      SiteSetting.enable_imap = true
      incoming =
        Fabricate(:incoming_email, imap_sync: true, post: post, topic: post.topic, imap_uid: 99)
      PostDestroyer.new(moderator, post).recover
      incoming.reload
      expect(incoming.imap_sync).to eq(false)
    end
  end

  describe "basic destroying" do
    it "as the creator of the post, doesn't delete the post" do
      begin
        post2 = create_post
        user_stat = post2.user.user_stat

        called = 0
        topic_destroyed = ->(topic, user) do
          expect(topic).to eq(post2.topic)
          expect(user).to eq(post2.user)
          called += 1
        end

        DiscourseEvent.on(:topic_destroyed, &topic_destroyed)

        @orig = post2.cooked
        # Guardian.new(post2.user).can_delete_post?(post2) == false
        PostDestroyer.new(post2.user, post2).destroy
        post2.reload

        expect(post2.deleted_at).to be_blank
        expect(post2.deleted_by).to be_blank
        expect(post2.user_deleted).to eq(true)
        expect(post2.raw).to eq(I18n.t("js.topic.deleted_by_author_simple"))
        expect(post2.version).to eq(2)
        expect(called).to eq(1)
        expect(user_stat.reload.post_count).to eq(0)
        expect(user_stat.reload.topic_count).to eq(1)

        called = 0
        topic_recovered = ->(topic, user) do
          expect(topic).to eq(post2.topic)
          expect(user).to eq(post2.user)
          called += 1
        end

        DiscourseEvent.on(:topic_recovered, &topic_recovered)

        # lets try to recover
        PostDestroyer.new(post2.user, post2).recover
        post2.reload
        expect(post2.version).to eq(3)
        expect(post2.user_deleted).to eq(false)
        expect(post2.cooked).to eq(@orig)
        expect(called).to eq(1)
        expect(user_stat.reload.post_count).to eq(0)
        expect(user_stat.reload.topic_count).to eq(1)
      ensure
        DiscourseEvent.off(:topic_destroyed, &topic_destroyed)
        DiscourseEvent.off(:topic_recovered, &topic_recovered)
      end
    end

    it "maintains history when a user destroys a hidden post" do
      post.hide!(PostActionType.types[:inappropriate])
      PostDestroyer.new(post.user, post).destroy
      expect(post.revisions[0].modifications["raw"]).to be_present
    end

    it "when topic is destroyed, it updates user_stats correctly" do
      SiteSetting.min_topic_title_length = 5
      post.topic.update_column(:title, "xyz")

      user1 = post.user
      user2 = Fabricate(:user)
      reply = create_post(topic_id: post.topic_id, user: user2)
      reply2 = create_post(topic_id: post.topic_id, user: user1)
      expect(user1.user_stat.topic_count).to eq(1)
      expect(user1.user_stat.post_count).to eq(1)
      expect(user2.user_stat.topic_count).to eq(0)
      expect(user2.user_stat.post_count).to eq(1)

      PostDestroyer.new(admin, post).destroy
      user1.reload
      user2.reload
      expect(user1.user_stat.topic_count).to eq(0)
      expect(user1.user_stat.post_count).to eq(0)
      expect(user2.user_stat.topic_count).to eq(0)
      expect(user2.user_stat.post_count).to eq(0)
    end

    it "does not update post_count or topic_count to a negative number" do
      user1 = post.user
      reply2 = create_post(topic_id: post.topic_id, user: user1)
      expect(user1.user_stat.topic_count).to eq(1)
      expect(user1.user_stat.post_count).to eq(1)

      user1.user_stat.update!(topic_count: 0)
      user1.user_stat.update!(post_count: 0)

      PostDestroyer.new(admin, post).destroy
      user1.reload
      expect(user1.user_stat.topic_count).to eq(0)
      expect(user1.user_stat.post_count).to eq(0)
    end

    it "deletes the published page associated with the topic" do
      slug = "my-published-page"
      publish_result = PublishedPage.publish!(admin, post.topic, slug)
      pp = publish_result.last
      expect(publish_result.first).to eq(true)

      PostDestroyer.new(admin, post).destroy

      expect(PublishedPage.find_by(id: pp.id)).to be_nil
    end

    it "accepts a delete_removed_posts_after option" do
      SiteSetting.delete_removed_posts_after = 0

      post.update!(post_number: 2)

      PostDestroyer.new(post.user, post, delete_removed_posts_after: 1).destroy

      post.reload

      expect(post.deleted_at).to eq(nil)
      expect(post.user_deleted).to eq(true)

      expect(post.raw).to eq(I18n.t("js.post.deleted_by_author_simple"))
    end

    it "runs the SyncTopicUserBookmarked for the topic that the post is in so topic_users.bookmarked is correct" do
      post2 = create_post
      PostDestroyer.new(post2.user, post2).destroy
      expect_job_enqueued(job: :sync_topic_user_bookmarked, args: { topic_id: post2.topic_id })
    end

    it "skips post revise validations when post is marked for deletion by the author" do
      SiteSetting.min_first_post_length = 100
      post =
        create_post(
          raw: "this is a long post what passes the min_first_post_length validation " * 3,
        )
      PostDestroyer.new(post.user, post).destroy
      post.reload
      expect(post.errors).to be_blank
      expect(post.revisions.count).to eq(1)
      expect(post.raw).to eq(I18n.t("js.topic.deleted_by_author_simple"))
      expect(post.user_deleted).to eq(true)
      expect(post.topic.closed).to eq(true)
    end

    context "as a moderator" do
      it "deletes the post" do
        author = post.user
        reply = create_post(topic_id: post.topic_id, user: author)

        post_count = author.post_count
        history_count = UserHistory.count

        PostDestroyer.new(moderator, reply).destroy

        expect(reply.deleted_at).to be_present
        expect(reply.deleted_by).to eq(moderator)

        author.reload
        expect(author.post_count).to eq(post_count - 1)
        expect(UserHistory.count).to eq(history_count + 1)
      end
    end

    context "when deleted by user with access to moderate topic category" do
      fab!(:review_user) { Fabricate(:user) }

      before do
        SiteSetting.enable_category_group_moderation = true
        review_group = Fabricate(:group)
        review_category = Fabricate(:category)
        Fabricate(:category_moderation_group, category: review_category, group: review_group)
        post.topic.update!(category: review_category)
        review_group.users << review_user
      end

      context "when the post has a reviewable" do
        it "deletes the post" do
          author = post.user
          reply = create_post(topic_id: post.topic_id, user: author)
          ReviewableFlaggedPost.needs_review!(target: reply, created_by: Fabricate(:user))

          post_count = author.post_count
          history_count = UserHistory.count

          PostDestroyer.new(review_user, reply).destroy

          expect(reply.deleted_at).to be_present
          expect(reply.deleted_by).to eq(review_user)

          author.reload
          expect(author.post_count).to eq(post_count - 1)
          expect(UserHistory.count).to eq(history_count + 1)
        end
      end
    end

    context "as an admin" do
      it "deletes the post" do
        PostDestroyer.new(admin, post).destroy
        expect(post.deleted_at).to be_present
        expect(post.deleted_by).to eq(admin)
      end

      it "updates the user's topic_count for first post" do
        author = post.user
        expect {
          PostDestroyer.new(admin, post).destroy
          author.reload
        }.to change { author.topic_count }.by(-1)
        expect(author.user_stat.post_count).to eq(0)
      end

      it "updates the user's post_count for reply" do
        author = post.user
        reply = create_post(topic: post.topic, user: author)
        expect {
          PostDestroyer.new(admin, reply).destroy
          author.reload
        }.to change { author.post_count }.by(-1)
        expect(author.user_stat.topic_count).to eq(1)
      end

      it "doesn't count whispers" do
        user_stat = admin.user_stat
        whisper =
          PostCreator.new(
            admin,
            topic_id: post.topic.id,
            reply_to_post_number: 1,
            post_type: Post.types[:whisper],
            raw: "this is a whispered reply",
          ).create
        expect(user_stat.reload.post_count).to eq(0)
        expect { PostDestroyer.new(admin, whisper).destroy }.to_not change {
          user_stat.reload.post_count
        }
      end
    end
  end

  describe "private message" do
    fab!(:author) { Fabricate(:user) }
    fab!(:private_message) { Fabricate(:private_message_topic, user: author) }
    fab!(:first_post) { Fabricate(:post, topic: private_message, user: author) }
    fab!(:second_post) { Fabricate(:post, topic: private_message, user: author, post_number: 2) }

    it "doesn't update post_count for a reply" do
      expect {
        PostDestroyer.new(admin, second_post).destroy
        author.reload
      }.to_not change { author.post_count }

      expect { PostDestroyer.new(admin, second_post).recover }.to_not change { author.post_count }
    end

    it "doesn't update topic_count for first post" do
      expect {
        PostDestroyer.new(admin, first_post).destroy
        author.reload
      }.to_not change { author.topic_count }
      expect(author.post_count).to eq(0) # also unchanged
    end

    it "triggers the extensibility events" do
      events = DiscourseEvent.track_events { PostDestroyer.new(admin, first_post).destroy }.last(2)

      expect(events[0][:event_name]).to eq(:post_destroyed)
      expect(events[0][:params].first).to eq(first_post)

      expect(events[1][:event_name]).to eq(:topic_destroyed)
      expect(events[1][:params].first).to eq(first_post.topic)
    end

    it "should not log a personal message view" do
      SiteSetting.log_personal_messages_views = true
      Fabricate(:topic_web_hook)
      StaffActionLogger.any_instance.expects(:log_check_personal_message).never
      PostDestroyer.new(admin, first_post).destroy
    end
  end

  describe "deleting a post directly after a whisper" do
    before { SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}" }

    it "should not set Topic#last_post_user_id to a whisperer" do
      post_1 = create_post(topic: post.topic, user: moderator)
      create_post(topic: post.topic, user: Fabricate(:user), post_type: Post.types[:whisper])
      whisper_2 =
        create_post(topic: post.topic, user: Fabricate(:user), post_type: Post.types[:whisper])

      PostDestroyer.new(admin, whisper_2).destroy

      expect(post.topic.reload.last_post_user_id).to eq(post_1.user.id)
    end
  end

  describe "deleting the second post in a topic" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    let!(:post) { create_post(user: user) }
    let(:topic) { post.topic }
    fab!(:second_user) { coding_horror }
    let!(:second_post) { create_post(topic: topic, user: second_user) }

    before do
      PostDestroyer.new(moderator, second_post).destroy
      topic.reload
    end

    it "resets the last_poster_id back to the OP" do
      expect(topic.last_post_user_id).to eq(user.id)
    end

    it "resets the last_posted_at back to the OP" do
      expect(topic.last_posted_at.to_i).to eq(post.created_at.to_i)
    end

    it "resets the highest_post_number" do
      expect(topic.highest_post_number).to eq(post.post_number)
    end

    context "with topic_user" do
      let(:topic_user) { second_user.topic_users.find_by(topic_id: topic.id) }

      it "clears the posted flag for the second user" do
        expect(topic_user.posted?).to eq(false)
      end

      it "sets the second user's last_read_post_number back to 1" do
        expect(topic_user.last_read_post_number).to eq(1)
      end
    end
  end

  describe "deleting a post belonging to a deleted topic" do
    let!(:topic) { post.topic }
    let(:author) { post.user }

    before do
      topic.trash!(admin)
      post.reload
    end

    context "as a moderator" do
      before { PostDestroyer.new(moderator, post).destroy }

      it "deletes the post" do
        expect(post.deleted_at).to be_present
        expect(post.deleted_by).to eq(moderator)
        expect(author.user_stat.post_count).to eq(0)
      end
    end

    context "as an admin" do
      subject(:destroyer) { PostDestroyer.new(admin, post).destroy }

      it "deletes the post" do
        destroyer
        expect(post.deleted_at).to be_present
        expect(post.deleted_by).to eq(admin)
      end

      it "creates a new user history entry" do
        expect { destroyer }.to change { UserHistory.count }.by(1)
      end

      it "triggers a extensibility event" do
        events = DiscourseEvent.track_events { destroyer }

        expect(events[0][:event_name]).to eq(:post_destroyed)
        expect(events[0][:params].first).to eq(post)
      end
    end
  end

  describe "deleting a reply belonging to a deleted topic" do
    let!(:topic) { post.topic }
    let!(:reply) { create_post(topic_id: topic.id, user: post.user) }
    let(:author) { reply.user }

    before do
      topic.trash!(admin)
      post.reload
      reply.reload
    end

    context "as a moderator" do
      subject(:destroyer) { PostDestroyer.new(moderator, reply).destroy }

      it "deletes the reply" do
        destroyer
        expect(reply.deleted_at).to be_present
        expect(reply.deleted_by).to eq(moderator)
      end

      it "doesn't decrement post_count again" do
        expect { destroyer }.to_not change { author.user_stat.post_count }
      end
    end

    context "as an admin" do
      subject(:destroyer) { PostDestroyer.new(admin, reply).destroy }

      it "deletes the post" do
        destroyer
        expect(reply.deleted_at).to be_present
        expect(reply.deleted_by).to eq(admin)
      end

      it "doesn't decrement post_count again" do
        expect { destroyer }.to_not change { author.user_stat.post_count }
      end

      it "creates a new user history entry" do
        expect { destroyer }.to change { UserHistory.count }.by(1)
      end
    end
  end

  it "deletes a post belonging to a non-existent topic" do
    DB.exec("DELETE FROM topics WHERE id = ?", post.topic_id)
    post.reload

    PostDestroyer.new(admin, post).destroy

    expect(post.deleted_at).to be_present
    expect(post.deleted_by).to eq(admin)
  end

  describe "after delete" do
    fab!(:coding_horror) { coding_horror }
    fab!(:post) { Fabricate(:post, raw: "Hello @CodingHorror") }

    it "should feature the users again (in case they've changed)" do
      expect_enqueued_with(job: :feature_topic_users, args: { topic_id: post.topic_id }) do
        PostDestroyer.new(moderator, post).destroy
      end
    end

    describe "incoming email and imap sync" do
      fab!(:incoming) { Fabricate(:incoming_email, post: post, topic: post.topic) }

      it "does nothing if imap not enabled" do
        IncomingEmail.expects(:find_by).never
        PostDestroyer.new(moderator, post).destroy
      end

      it "does nothing if the incoming email has no imap_uid" do
        SiteSetting.enable_imap = true
        PostDestroyer.new(moderator, post).destroy
        expect(incoming.reload.imap_sync).to eq(false)
      end

      it "sets imap_sync to true for the matching incoming" do
        SiteSetting.enable_imap = true
        incoming.update(imap_uid: 999)
        PostDestroyer.new(moderator, post).destroy
        expect(incoming.reload.imap_sync).to eq(true)
      end
    end

    context "with a reply" do
      fab!(:reply) { Fabricate(:basic_reply, user: coding_horror, topic: post.topic) }
      let!(:post_reply) { PostReply.create(post_id: post.id, reply_post_id: reply.id) }

      it "changes the post count of the topic" do
        post.reload
        expect {
          PostDestroyer.new(moderator, reply).destroy
          post.topic.reload
        }.to change(post.topic, :posts_count).by(-1)
      end

      it "lowers the reply_count when the reply is deleted" do
        expect { PostDestroyer.new(moderator, reply).destroy }.to change(
          post.post_replies,
          :count,
        ).by(-1)
      end

      it "should increase the post_number when there are deletion gaps" do
        PostDestroyer.new(moderator, reply).destroy
        p = Fabricate(:post, user: post.user, topic: post.topic)
        expect(p.post_number).to eq(3)
      end
    end
  end

  describe "@mentions" do
    it "removes notifications when deleted" do
      Jobs.run_immediately!
      user = Fabricate(:evil_trout)
      post = create_post(raw: "Hello @eviltrout")
      expect { PostDestroyer.new(moderator, post).destroy }.to change(
        user.notifications,
        :count,
      ).by(-1)
    end
  end

  describe "post actions" do
    let(:second_post) { Fabricate(:post, topic_id: post.topic_id) }
    let(:flag_result) { PostActionCreator.off_topic(moderator, second_post) }
    let!(:flag) { flag_result.post_action }

    before { Jobs::SendSystemMessage.clear }

    it "should delete public post actions and agree with flags" do
      url = second_post.url
      PostDestroyer.new(moderator, second_post).destroy

      off_topic = PostAction.find_by(id: flag.id)
      expect(off_topic).not_to eq(nil)
      expect(off_topic.agreed_at).not_to eq(nil)

      second_post.reload
      expect(second_post.off_topic_count).to eq(1)

      jobs = Jobs::SendSystemMessage.jobs
      expect(jobs.size).to eq(1)

      Jobs::SendSystemMessage.new.execute(jobs[0]["args"][0].with_indifferent_access)

      expect(Post.last.raw).to eq(
        I18n.t(
          "system_messages.flags_agreed_and_post_deleted.text_body_template",
          flagged_post_raw_content: second_post.raw,
          url: url,
          flag_reason:
            I18n.t(
              "flag_reasons.#{PostActionType.flag_types[off_topic.post_action_type_id]}",
              locale: SiteSetting.default_locale,
              base_path: Discourse.base_path,
            ),
          site_name: SiteSetting.title,
          base_url: Discourse.base_url,
        ).strip,
      )
    end

    it "should not send the flags_agreed_and_post_deleted message if it was deleted by system" do
      expect(ReviewableFlaggedPost.pending.count).to eq(1)
      PostDestroyer.new(Discourse.system_user, second_post).destroy
      expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
      expect(ReviewableFlaggedPost.pending.count).to eq(0)
    end

    it "should not send the flags_agreed_and_post_deleted message if it was deleted by author" do
      SiteSetting.delete_removed_posts_after = 0
      expect(ReviewableFlaggedPost.pending.count).to eq(1)
      PostDestroyer.new(second_post.user, second_post).destroy
      expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
      expect(ReviewableFlaggedPost.pending.count).to eq(0)
    end

    it "should not send the flags_agreed_and_post_deleted message if flags were ignored" do
      expect(ReviewableFlaggedPost.pending.count).to eq(1)
      flag_result.reviewable.perform(moderator, :ignore_and_do_nothing)
      second_post.reload
      expect(ReviewableFlaggedPost.pending.count).to eq(0)

      PostDestroyer.new(moderator, second_post).destroy
      expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
    end

    it "should not send the flags_agreed_and_post_deleted message if defer_flags is true" do
      expect(ReviewableFlaggedPost.pending.count).to eq(1)
      PostDestroyer.new(moderator, second_post, defer_flags: true).destroy
      expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
      expect(ReviewableFlaggedPost.pending.count).to eq(0)
    end

    context "when custom flags" do
      fab!(:custom_flag) { Fabricate(:flag, name: "custom flag", notify_type: true) }
      let(:third_post) { Fabricate(:post, topic_id: post.topic_id) }

      it "should send message to user with correct translation" do
        PostActionCreator.new(
          moderator,
          third_post,
          custom_flag.id,
          is_warning: false,
          flag_topic: true,
        ).perform
        PostDestroyer.new(moderator, third_post, { reviewable: Reviewable.last }).destroy
        jobs = Jobs::SendSystemMessage.jobs
        expect(jobs.size).to eq(1)

        Jobs::SendSystemMessage.new.execute(jobs[0]["args"][0].with_indifferent_access)

        expect(Post.last.raw).to match("custom flag")
        custom_flag.destroy!
      end
    end
  end

  describe "user actions" do
    let(:codinghorror) { coding_horror }
    let(:second_post) { Fabricate(:post, topic_id: post.topic_id) }

    def create_user_action(action_type)
      UserAction.log_action!(
        action_type: action_type,
        user_id: codinghorror.id,
        acting_user_id: codinghorror.id,
        target_topic_id: second_post.topic_id,
        target_post_id: second_post.id,
      )
    end

    it "should delete the user actions" do
      like = create_user_action(UserAction::LIKE)

      PostDestroyer.new(moderator, second_post).destroy

      expect(UserAction.find_by(id: like.id)).to be_nil
    end
  end

  describe "topic links" do
    fab!(:first_post) { Fabricate(:post) }
    let!(:topic) { first_post.topic }
    let!(:second_post) { Fabricate(:post_with_external_links, topic: topic) }

    before { TopicLink.extract_from(second_post) }

    it "should destroy the topic links when moderator destroys the post" do
      PostDestroyer.new(moderator, second_post.reload).destroy
      expect(topic.topic_links.count).to eq(0)
    end

    it "should destroy the topic links when the user destroys the post" do
      PostDestroyer.new(second_post.user, second_post.reload).destroy
      expect(topic.topic_links.count).to eq(0)
    end
  end

  describe "internal links" do
    fab!(:topic)
    let!(:second_post) { Fabricate(:post, topic: topic) }
    fab!(:other_topic) { Fabricate(:topic) }
    let!(:other_post) { Fabricate(:post, topic: other_topic) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    let!(:base_url) { URI.parse(Discourse.base_url) }
    let!(:guardian) { Guardian.new }
    let!(:url) do
      "http://#{base_url.host}/t/#{other_topic.slug}/#{other_topic.id}/#{other_post.post_number}"
    end

    it "should destroy internal links when user deletes own post" do
      new_post = Post.create!(user: user, topic: topic, raw: "Link to other topic:\n\n#{url}\n")
      TopicLink.extract_from(new_post)

      link_counts = TopicLink.counts_for(guardian, other_topic.reload, [other_post])
      expect(link_counts.count).to eq(1)

      PostDestroyer.new(user, new_post).destroy

      updated_link_counts = TopicLink.counts_for(guardian, other_topic.reload, [other_post])
      expect(updated_link_counts.count).to eq(0)
    end

    it "should destroy internal links when moderator deletes post" do
      new_post = create_post(user: user, topic: topic, raw: "Link to other topic:\n\n#{url}\n")
      TopicLink.extract_from(new_post)
      link_counts = TopicLink.counts_for(guardian, other_topic.reload, [other_post])
      expect(link_counts.count).to eq(1)

      PostDestroyer.new(moderator, new_post).destroy
      TopicLink.extract_from(new_post)
      updated_link_counts = TopicLink.counts_for(guardian, other_topic, [other_post])

      expect(updated_link_counts.count).to eq(0)
    end
  end

  describe ".delete_with_replies" do
    subject(:delete_with_replies) do
      PostDestroyer.delete_with_replies(reporter, post, defer_reply_flags: defer_reply_flags)
    end

    fab!(:post)
    let(:reporter) { Discourse.system_user }
    let(:reply) { Fabricate(:post, topic: post.topic) }
    let(:reviewable_reply) { PostActionCreator.off_topic(reporter, reply).reviewable }

    before do
      post.update(replies: [reply])
      PostActionCreator.off_topic(reporter, post)
      reviewable_reply
    end

    context "when deferring reply flags" do
      let(:defer_reply_flags) { true }

      it "ignores flagged replies" do
        delete_with_replies
        expect(reviewable_reply.reload).to be_ignored
      end
    end

    context "when not deferring reply flags" do
      let(:defer_reply_flags) { false }

      it "approves flagged replies" do
        delete_with_replies
        expect(reviewable_reply.reload).to be_approved
      end
    end
  end

  describe "featured topics for user_profiles" do
    fab!(:user)

    it "clears the user_profiles featured_topic column" do
      user.user_profile.update(featured_topic: post.topic)
      PostDestroyer.new(admin, post).destroy
      expect(user.user_profile.reload.featured_topic).to eq(nil)
    end
  end

  describe "permanent destroy" do
    fab!(:private_message_topic)
    fab!(:private_post) { Fabricate(:private_message_post, topic: private_message_topic) }
    fab!(:post_action) { Fabricate(:post_action, post: private_post) }
    fab!(:reply) { Fabricate(:private_message_post, topic: private_message_topic) }
    fab!(:post_revision) { Fabricate(:post_revision, post: private_post) }
    fab!(:upload1) { Fabricate(:upload_s3, created_at: 5.hours.ago) }
    fab!(:upload_reference) { UploadReference.create(target: private_post, upload: upload1) }

    it "destroys the post and topic if deleting first post" do
      PostDestroyer.new(reply.user, reply, permanent: true).destroy
      expect { reply.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(private_message_topic.reload.persisted?).to be true

      PostDestroyer.new(private_post.user, private_post, permanent: true).destroy
      expect { private_post.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { private_message_topic.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { post_action.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { post_revision.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { upload_reference.reload }.to raise_error(ActiveRecord::RecordNotFound)

      Jobs::CleanUpUploads.new.reset_last_cleanup!
      SiteSetting.clean_orphan_uploads_grace_period_hours = 1
      Jobs::CleanUpUploads.new.execute({})
      expect { upload1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "soft delete if not creator of post or not private message" do
      PostDestroyer.new(moderator, reply, permanent: true).destroy
      expect(reply.deleted_at).not_to eq(nil)

      PostDestroyer.new(post.user, post, permanent: true).destroy
      expect(post.user_deleted).to be true

      expect(post_revision.reload.persisted?).to be true
    end

    it "destroys the post when force_destroy is true for soft deleted topics" do
      post = Fabricate(:post)
      topic = post.topic

      PostDestroyer.new(moderator, post).destroy
      post = Post.with_deleted.find_by(id: post.id)
      expect(post).not_to eq(nil)

      PostDestroyer.new(moderator, post, force_destroy: true).destroy
      post = Post.with_deleted.find_by(id: post.id)
      expect(post).to eq(nil)

      topic = Topic.with_deleted.find_by(id: topic.id)
      expect(topic).to eq(nil)
    end

    it "destroys the post when force_destroy is true for regular posts" do
      PostDestroyer.new(moderator, reply, force_destroy: true).destroy
      expect { reply.reload }.to raise_error(ActiveRecord::RecordNotFound)

      regular_post = Fabricate(:post)
      topic = regular_post.topic

      PostDestroyer.new(moderator, regular_post, force_destroy: true).destroy
      expect { regular_post.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { topic.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "destroys the post when force_destroy is true for posts by deleted users" do
      regular_post = Fabricate(:post, post_number: 2)
      UserDestroyer.new(admin).destroy(regular_post.user, delete_posts: true)
      regular_post.reload

      PostDestroyer.new(moderator, regular_post, force_destroy: true).destroy
      expect { regular_post.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "publishes messages to subscribers" do
    # timestamps are rounded because postgres truncates the timestamp. that would cause the comparison if we compared
    # these timestamps with the one read from the database
    fab!(:first_post) { Fabricate(:post, created_at: 10.days.ago.round) }
    fab!(:walter_white)
    let!(:topic) { first_post.topic }
    let!(:reply) do
      Fabricate(:post, topic: topic, created_at: 5.days.ago.round, user: coding_horror)
    end
    let!(:expendable_reply) do
      Fabricate(:post, topic: topic, created_at: 2.days.ago.round, user: walter_white)
    end

    it "when a post is destroyed publishes updated topic stats" do
      expect(topic.reload.posts_count).to eq(3)

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          PostDestroyer.new(moderator, expendable_reply, force_destroy: true).destroy
        end

      expect { expendable_reply.reload }.to raise_error(ActiveRecord::RecordNotFound)

      stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
      expect(stats_message).to be_present
      expect(stats_message.data[:posts_count]).to eq(2)
      expect(stats_message.data[:last_posted_at]).to eq(reply.created_at.as_json)
      expect(stats_message.data[:last_poster]).to eq(
        BasicUserSerializer.new(reply.user, root: false).as_json,
      )
    end

    it "when a post is deleted publishes updated topic stats" do
      expect(topic.reload.posts_count).to eq(3)

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          PostDestroyer.new(moderator, expendable_reply).destroy
        end

      expect(expendable_reply.reload.deleted_at).not_to eq(nil)

      stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
      expect(stats_message).to be_present
      expect(stats_message.data[:posts_count]).to eq(2)
      expect(stats_message.data[:last_posted_at]).to eq(reply.created_at.as_json)
      expect(stats_message.data[:last_poster]).to eq(
        BasicUserSerializer.new(reply.user, root: false).as_json,
      )
    end

    it "when a post is recovered publishes update topic stats" do
      expect(topic.reload.posts_count).to eq(3)

      PostDestroyer.new(moderator, expendable_reply).destroy
      expect(topic.reload.posts_count).to eq(2)

      expendable_reply.reload

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          PostDestroyer.new(admin, expendable_reply).recover
        end

      expect(topic.reload.posts_count).to eq(3)

      stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
      expect(stats_message).to be_present
      expect(stats_message.data[:posts_count]).to eq(3)
      expect(stats_message.data[:last_posted_at]).to eq(expendable_reply.created_at.as_json)
      expect(stats_message.data[:last_poster]).to eq(
        BasicUserSerializer.new(expendable_reply.user, root: false).as_json,
      )
    end
  end

  describe "mailing_list_mode emails on recovery" do
    fab!(:topic)
    fab!(:post_1) { Fabricate(:post, topic: topic) }
    fab!(:post_2) { Fabricate(:post, topic: topic) }

    it "enqueues the notify_mailing_list_subscribers_job for the post" do
      PostDestroyer.new(admin, post_2).destroy
      post_2.reload
      expect_enqueued_with(job: :notify_mailing_list_subscribers, args: { post_id: post_2.id }) do
        PostDestroyer.new(admin, post_2).recover
      end
    end

    it "enqueues the notify_mailing_list_subscribers_job for the op" do
      PostDestroyer.new(admin, post_1).destroy
      post_1.reload
      expect_enqueued_with(job: :notify_mailing_list_subscribers, args: { post_id: post_1.id }) do
        PostDestroyer.new(admin, post_1).recover
      end
    end
  end
end
