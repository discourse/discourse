# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)
  fab!(:evil_trout) { Fabricate(:evil_trout, refresh_auto_groups: true) }

  describe "#move_types" do
    context "when verifying enum sequence" do
      before { @move_types = PostMover.move_types }

      it "'new_topic' should be at 1st position" do
        expect(@move_types[:new_topic]).to eq(1)
      end

      it "'existing_topic' should be at 2nd position" do
        expect(@move_types[:existing_topic]).to eq(2)
      end
    end
  end

  describe "move_posts" do
    context "with topics" do
      before { freeze_time }

      fab!(:user) { Fabricate(:admin) }
      fab!(:another_user) { evil_trout }
      fab!(:category) { Fabricate(:category, user: user) }
      fab!(:topic) { Fabricate(:topic, user: user, created_at: 4.hours.ago) }
      fab!(:p1) do
        Fabricate(:post, topic: topic, user: user, created_at: 3.hours.ago, reply_count: 2)
      end

      fab!(:p2) do
        Fabricate(
          :post,
          topic: topic,
          user: another_user,
          raw: "Has a link to [evil trout](http://eviltrout.com) which is a cool site.",
          reply_to_post_number: p1.post_number,
          reply_count: 1,
          created_at: 2.hours.ago,
        )
      end

      fab!(:p3) do
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: p1.post_number,
          user: user,
          created_at: 1.hour.ago,
        )
      end
      fab!(:p4) do
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: p2.post_number,
          user: user,
          created_at: 45.minutes.ago,
        )
      end
      fab!(:p5) { Fabricate(:post, created_at: 30.minutes.ago) }
      let(:p6) { Fabricate(:post, topic: topic, created_at: 15.minutes.ago) }

      before do
        SiteSetting.tagging_enabled = true
        Jobs.run_immediately!
        p1.replies.push(p2, p3)
        p2.replies.push(p4)
        UserActionManager.enable
        @like = PostActionCreator.like(another_user, p4)
      end

      def add_moderator_post_to(topic, post_type)
        topic.add_moderator_post(user, "message", post_type: post_type, action_code: "split_topic")
      end

      context "with success" do
        it "correctly handles notifications and bread crumbs" do
          old_topic = p2.topic

          old_topic_id = p2.topic_id

          topic.move_posts(user, [p2.id, p4.id, p6.id], title: "new testing topic name")

          p2.reload
          expect(p2.topic_id).not_to eq(old_topic_id)
          expect(p2.reply_to_post_number).to eq(nil)
          expect(p2.reply_to_user_id).to eq(nil)

          notification =
            p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

          expect(notification.topic_id).to eq(p2.topic_id)
          expect(notification.topic_id).not_to eq(old_topic_id)
          expect(notification.post_number).to eq(1)

          # no message for person who made the move
          expect(
            p4.user.notifications.where(notification_type: Notification.types[:moved_post]).length,
          ).to eq(0)

          # notify at the right spot in the stream
          notification =
            p6.user.notifications.where(notification_type: Notification.types[:moved_post]).first

          expect(notification.topic_id).to eq(p2.topic_id)
          expect(notification.topic_id).not_to eq(old_topic_id)

          # this is the 3rd post we moved
          expect(notification.post_number).to eq(3)

          old_topic.reload
          move_message = old_topic.posts.find_by(post_number: 2)
          expect(move_message.post_type).to eq(Post.types[:small_action])
          expect(move_message.raw).to include("3 posts were split")
        end

        it "correctly remaps quotes" do
          raw = <<~RAW
            [quote="dan, post:#{p2.post_number}, topic:#{p2.topic_id}, full:true"]
            some quote from the other post
            [/quote]

            the quote above should be updated with new post number and topic id
          RAW

          p3.update!(raw: raw)
          p3.rebake!

          expect { topic.move_posts(user, [p2.id], title: "new testing topic name") }.to change {
            p2.reload.topic_id
          }.and change { p2.post_number }.and change { p3.reload.raw }.and change {
                              p2.baked_version
                            }.to(nil).and change { p3.baked_version }.to(nil)

          expect(p3.raw).to include("post:#{p2.post_number}, topic:#{p2.topic_id}")
        end
      end

      context "with errors" do
        it "raises an error when one of the posts doesn't exist" do
          non_existent_post_id = Post.maximum(:id)&.next || 1
          expect {
            topic.move_posts(user, [non_existent_post_id], title: "new testing topic name")
          }.to raise_error(Discourse::InvalidParameters)
        end

        it "raises an error and does not create a topic if no posts were moved" do
          Topic.count.tap do |original_topic_count|
            expect { topic.move_posts(user, [], title: "new testing topic name") }.to raise_error(
              Discourse::InvalidParameters,
            )

            expect(Topic.count).to eq original_topic_count
          end
        end
      end

      context "when successfully moved" do
        before do
          TopicUser.update_last_read(user, topic.id, p4.post_number, p4.post_number, 0)
          TopicLink.extract_from(p2)
        end

        def create_post_timing(post, user, msecs)
          PostTiming.create!(
            topic_id: post.topic_id,
            user_id: user.id,
            post_number: post.post_number,
            msecs: msecs,
          )
        end

        context "with post replies" do
          describe "when a post with replies is moved" do
            it "should update post replies correctly" do
              topic.move_posts(
                user,
                [p2.id],
                title: "GOT is a very addictive show",
                category_id: category.id,
              )

              expect(p2.reload.replies).to eq([])
            end

            it "doesn't raise errors with deleted replies" do
              p4.trash!
              topic.move_posts(
                user,
                [p2.id],
                title: "GOT is a very addictive show",
                category_id: category.id,
              )

              expect(p2.reload.replies).to eq([])
            end
          end

          describe "when replies of a post have been moved" do
            it "should update post replies correctly" do
              p5 =
                Fabricate(
                  :post,
                  topic: topic,
                  reply_to_post_number: p2.post_number,
                  user: another_user,
                )

              p2.replies << p5

              topic.move_posts(
                user,
                [p4.id],
                title: "GOT is a very addictive show",
                category_id: category.id,
              )

              expect(p2.reload.replies).to eq([p5])
            end
          end

          context "when only one reply is left behind" do
            it "should update post replies correctly" do
              p5 =
                Fabricate(
                  :post,
                  topic: topic,
                  reply_to_post_number: p2.post_number,
                  user: another_user,
                )

              p2.replies << p5

              topic.move_posts(
                user,
                [p2.id, p4.id],
                title: "GOT is a very addictive show",
                category_id: category.id,
              )

              expect(p2.reload.replies).to eq([p4])
            end
          end
        end

        context "when moved to a new topic" do
          it "works correctly" do
            topic.expects(:add_moderator_post).once
            new_topic =
              topic.move_posts(
                user,
                [p2.id, p4.id],
                title: "new testing topic name",
                category_id: category.id,
                tags: %w[tag1 tag2],
              )

            expect(
              TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number,
            ).to eq(p3.post_number)

            expect(new_topic).to be_present
            expect(new_topic.featured_user1_id).to eq(p4.user_id)
            expect(new_topic.like_count).to eq(1)

            expect(new_topic.category).to eq(category)
            expect(new_topic.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
            expect(topic.featured_user1_id).to be_blank
            expect(new_topic.posts.by_post_number).to match_array([p2, p4])

            new_topic.reload
            expect(new_topic.posts_count).to eq(2)
            expect(new_topic.highest_post_number).to eq(2)

            p4.reload
            expect(new_topic.last_post_user_id).to eq(p4.user_id)
            expect(new_topic.last_posted_at).to eq_time(p4.created_at)
            expect(new_topic.bumped_at).to eq_time(Time.zone.now)

            p2.reload
            expect(p2.sort_order).to eq(1)
            expect(p2.post_number).to eq(1)
            expect(p2.topic_links.first.topic_id).to eq(new_topic.id)

            expect(p4.post_number).to eq(2)
            expect(p4.sort_order).to eq(2)

            topic.reload
            expect(topic.featured_user1_id).to be_blank
            expect(topic.like_count).to eq(0)
            expect(topic.posts_count).to eq(2)
            expect(topic.posts.by_post_number).to match_array([p1, p3])
            expect(topic.highest_post_number).to eq(p3.post_number)

            # both the like and was_liked user actions should be correct
            action = UserAction.find_by(user_id: another_user.id)
            expect(action.target_topic_id).to eq(new_topic.id)

            expect(
              TopicUser.exists?(
                user_id: another_user,
                topic_id: new_topic.id,
                notification_level: TopicUser.notification_levels[:watching],
                notifications_reason_id: TopicUser.notification_reasons[:created_topic],
              ),
            ).to eq(true)
            expect(TopicUser.exists?(user_id: user, topic_id: new_topic.id)).to eq(true)

            # moved_post records are created correctly
            expect(
              MovedPost.exists?(
                new_topic: new_topic,
                new_post_id: p2.id,
                old_topic: topic,
                old_post_id: p2.id,
                created_new_topic: true,
              ),
            ).to eq(true)
            expect(
              MovedPost.exists?(
                new_topic: new_topic,
                new_post_id: p4.id,
                old_topic: topic,
                old_post_id: p4.id,
                created_new_topic: true,
              ),
            ).to eq(true)
          end

          it "moving all posts will close the topic" do
            topic.expects(:add_moderator_post).twice
            new_topic =
              topic.move_posts(
                user,
                [p1.id, p2.id, p3.id, p4.id],
                title: "new testing topic name",
                category_id: category.id,
              )
            expect(new_topic).to be_present

            topic.reload
            expect(topic.closed).to eq(true)
          end

          it "does not move posts that do not belong to the existing topic" do
            new_topic =
              topic.move_posts(user, [p2.id, p3.id, p5.id], title: "Logan is a pretty good movie")

            expect(new_topic.posts.pluck(:id).sort).to eq([p2.id, p3.id].sort)
          end

          it "uses default locale for moderator post" do
            I18n.locale = "de"

            new_topic =
              topic.move_posts(
                user,
                [p2.id, p4.id],
                title: "new testing topic name",
                category_id: category.id,
              )
            post = Post.find_by(topic_id: topic.id, post_type: Post.types[:small_action])

            expected_text =
              I18n.with_locale(:en) do
                I18n.t(
                  "move_posts.new_topic_moderator_post",
                  count: 2,
                  topic_link: "[#{new_topic.title}](#{new_topic.relative_url})",
                )
              end

            expect(post.raw).to eq(expected_text)
          end

          it "does not try to move small action posts" do
            small_action =
              Fabricate(
                :post,
                topic: topic,
                raw: "A small action",
                post_type: Post.types[:small_action],
              )
            hidden_small_action = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
            hidden_small_action.update_attribute(:raw, "")
            new_topic =
              topic.move_posts(
                user,
                [p2.id, p4.id, small_action.id, hidden_small_action.id],
                title: "new testing topic name",
                category_id: category.id,
              )

            expect(new_topic.posts_count).to eq(2)
            expect(small_action.topic_id).to eq(topic.id)
            expect(hidden_small_action.topic_id).to eq(topic.id)

            moderator_post = topic.posts.last
            expect(moderator_post.raw).to include("2 posts were split")
          end

          it "forces resulting topic owner to watch the new topic" do
            new_topic =
              topic.move_posts(
                user,
                [p2.id, p4.id],
                title: "new testing topic name",
                category_id: category.id,
              )

            expect(new_topic.posts_count).to eq(2)

            expect(
              TopicUser.exists?(
                user_id: another_user,
                topic_id: new_topic.id,
                notification_level: TopicUser.notification_levels[:watching],
                notifications_reason_id: TopicUser.notification_reasons[:created_topic],
              ),
            ).to eq(true)
          end

          it "updates existing notifications" do
            n3 = Fabricate(:mentioned_notification, post: p3, user: another_user)
            n4 = Fabricate(:mentioned_notification, post: p4, user: another_user)

            new_topic = topic.move_posts(user, [p3.id], title: "new testing topic name")

            n3 = Notification.find(n3.id)
            expect(n3.topic_id).to eq(new_topic.id)
            expect(n3.post_number).to eq(1)
            expect(n3.data_hash[:topic_title]).to eq(new_topic.title)

            n4 = Notification.find(n4.id)
            expect(n4.topic_id).to eq(topic.id)
            expect(n4.post_number).to eq(4)
          end

          it "doesn't update notifications of type 'watching_first_post'" do
            n1 = Fabricate(:watching_first_post_notification, post: p1, user: another_user)

            topic.move_posts(user, [p1.id], title: "new testing topic name")

            n1 = Notification.find(n1.id)
            expect(n1.topic_id).to eq(topic.id)
            expect(n1.data_hash[:topic_title]).to eq(topic.title)
            expect(n1.post_number).to eq(1)
          end

          it "deletes notifications for users not allowed to see the topic" do
            another_admin = Fabricate(:admin)
            staff_category = Fabricate(:private_category, group: Group[:staff])
            user_notification = Fabricate(:mentioned_notification, post: p3, user: another_user)
            admin_notification = Fabricate(:mentioned_notification, post: p3, user: another_admin)

            topic.move_posts(
              user,
              [p3.id],
              title: "new testing topic name",
              category_id: staff_category.id,
            )

            expect(Notification.exists?(user_notification.id)).to eq(false)
            expect(Notification.exists?(admin_notification.id)).to eq(true)
          end

          it "moves post timings" do
            some_user = Fabricate(:user)
            create_post_timing(p1, some_user, 500)
            create_post_timing(p2, some_user, 1000)
            create_post_timing(p3, some_user, 1500)
            create_post_timing(p4, some_user, 750)

            new_topic = topic.move_posts(user, [p1.id, p4.id], title: "new testing topic name")

            expect(
              PostTiming.where(topic_id: topic.id, user_id: some_user.id).pluck(
                :post_number,
                :msecs,
              ),
            ).to contain_exactly([1, 500], [2, 1000], [3, 1500])

            expect(
              PostTiming.where(topic_id: new_topic.id, user_id: some_user.id).pluck(
                :post_number,
                :msecs,
              ),
            ).to contain_exactly([1, 500], [2, 750])
          end

          it "makes sure the topic_user.bookmarked value is reflected for users in the source and destination topic" do
            Jobs.run_immediately!
            user1 = Fabricate(:user)
            user2 = Fabricate(:user)

            bookmark1 = Fabricate(:bookmark, bookmarkable: p1, user: user1)
            bookmark2 = Fabricate(:bookmark, bookmarkable: p4, user: user1)

            bookmark3 = Fabricate(:bookmark, bookmarkable: p3, user: user2)
            bookmark4 = Fabricate(:bookmark, bookmarkable: p4, user: user2)

            tu1 =
              Fabricate(
                :topic_user,
                user: user1,
                topic: p1.topic,
                bookmarked: true,
                notification_level: TopicUser.notification_levels[:watching],
                last_read_post_number: 4,
                last_emailed_post_number: 3,
              )
            tu2 =
              Fabricate(
                :topic_user,
                user: user2,
                topic: p1.topic,
                bookmarked: true,
                notification_level: TopicUser.notification_levels[:watching],
                last_read_post_number: 4,
                last_emailed_post_number: 3,
              )

            new_topic = topic.move_posts(user, [p1.id, p4.id], title: "new testing topic name")
            new_topic_user1 = TopicUser.find_by(topic: new_topic, user: user1)
            new_topic_user2 = TopicUser.find_by(topic: new_topic, user: user2)

            original_topic_id = p1.topic_id
            expect(p1.reload.topic_id).to eq(original_topic_id)
            expect(p4.reload.topic_id).to eq(new_topic.id)

            expect(tu1.reload.bookmarked).to eq(false)
            expect(tu2.reload.bookmarked).to eq(true)
            expect(new_topic_user1.bookmarked).to eq(true)
            expect(new_topic_user2.bookmarked).to eq(true)
          end

          context "with read state and other stats per user" do
            def create_topic_user(user, opts = {})
              notification_level = opts.delete(:notification_level) || :regular

              Fabricate(
                :topic_user,
                opts.merge(
                  notification_level: TopicUser.notification_levels[notification_level],
                  topic: topic,
                  user: user,
                ),
              )
            end

            fab!(:user1) { Fabricate(:user) }
            fab!(:user2) { Fabricate(:user, refresh_auto_groups: true) }
            fab!(:user3) { Fabricate(:user, refresh_auto_groups: true) }
            fab!(:admin1) { Fabricate(:admin) }
            fab!(:admin2) { Fabricate(:admin) }

            it "correctly moves topic_user records" do
              create_topic_user(
                user1,
                last_read_post_number: 4,
                last_emailed_post_number: 3,
                notification_level: :tracking,
              )
              create_topic_user(
                user2,
                last_read_post_number: 2,
                last_emailed_post_number: 2,
                notification_level: :tracking,
              )
              create_topic_user(
                user3,
                last_read_post_number: 1,
                last_emailed_post_number: 4,
                notification_level: :watching,
              )

              p2.update!(user_id: user2.id)
              new_topic = topic.move_posts(user, [p1.id, p2.id], title: "new testing topic name")

              expect(TopicUser.where(topic_id: topic.id).count).to eq(4)
              expect(TopicUser.find_by(topic: topic, user: user)).to have_attributes(
                last_read_post_number: 4,
                last_emailed_post_number: nil,
                notification_level: TopicUser.notification_levels[:tracking],
              )
              expect(TopicUser.find_by(topic: topic, user: user1)).to have_attributes(
                last_read_post_number: 4,
                last_emailed_post_number: 3,
                notification_level: TopicUser.notification_levels[:tracking],
              )
              expect(TopicUser.find_by(topic: topic, user: user2)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 2,
                notification_level: TopicUser.notification_levels[:tracking],
              )
              expect(TopicUser.find_by(topic: topic, user: user3)).to have_attributes(
                last_read_post_number: 1,
                last_emailed_post_number: 4,
                notification_level: TopicUser.notification_levels[:watching],
              )

              expect(TopicUser.where(topic_id: new_topic.id).count).to eq(4)
              expect(TopicUser.find_by(topic: new_topic, user: user)).to have_attributes(
                last_read_post_number: 1,
                last_emailed_post_number: nil,
                notification_level: TopicUser.notification_levels[:watching],
                posted: true,
              )
              expect(TopicUser.find_by(topic: new_topic, user: user1)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 2,
                notification_level: TopicUser.notification_levels[:tracking],
                posted: false,
              )
              expect(TopicUser.find_by(topic: new_topic, user: user2)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 2,
                notification_level: TopicUser.notification_levels[:tracking],
                posted: true,
              )
              expect(TopicUser.find_by(topic: new_topic, user: user3)).to have_attributes(
                last_read_post_number: 1,
                last_emailed_post_number: 2,
                notification_level: TopicUser.notification_levels[:watching],
                posted: false,
              )
            end
          end
        end

        context "when moved to an existing topic" do
          fab!(:destination_topic) { Fabricate(:topic, user: another_user) }
          fab!(:destination_op) do
            Fabricate(:post, topic: destination_topic, user: another_user, created_at: 1.day.ago)
          end

          it "works correctly" do
            topic.expects(:add_moderator_post).once
            moved_to =
              topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id)
            expect(moved_to).to eq(destination_topic)

            # Check out new topic
            moved_to.reload
            expect(moved_to.posts_count).to eq(3)
            expect(moved_to.highest_post_number).to eq(3)
            expect(moved_to.user_id).to eq(destination_op.user_id)
            expect(moved_to.like_count).to eq(1)
            expect(moved_to.category_id).to eq(SiteSetting.uncategorized_category_id)
            p4.reload
            expect(moved_to.last_post_user_id).to eq(p4.user_id)
            expect(moved_to.last_posted_at).to eq_time(p4.created_at)
            expect(moved_to.bumped_at).to eq_time(Time.zone.now)

            # Posts should be re-ordered
            p2.reload
            expect(p2.sort_order).to eq(2)
            expect(p2.post_number).to eq(2)
            expect(p2.topic_id).to eq(moved_to.id)
            expect(p2.reply_count).to eq(1)
            expect(p2.reply_to_post_number).to eq(nil)

            expect(p4.post_number).to eq(3)
            expect(p4.sort_order).to eq(3)
            expect(p4.topic_id).to eq(moved_to.id)
            expect(p4.reply_count).to eq(0)
            expect(p4.reply_to_post_number).to eq(2)

            # Check out the original topic
            topic.reload
            expect(topic.posts_count).to eq(2)
            expect(topic.highest_post_number).to eq(3)
            expect(topic.featured_user1_id).to be_blank
            expect(topic.like_count).to eq(0)
            expect(topic.posts_count).to eq(2)
            expect(topic.posts.by_post_number).to match_array([p1, p3])
            expect(topic.highest_post_number).to eq(p3.post_number)

            # Should notify correctly
            notification =
              p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

            expect(notification.topic_id).to eq(destination_topic.id)
            expect(notification.post_number).to eq(p2.post_number)

            # Should update last reads
            expect(
              TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number,
            ).to eq(p3.post_number)

            expect(
              MovedPost.exists?(
                new_topic: destination_topic,
                new_post_id: p2.id,
                old_topic: topic,
                old_post_id: p2.id,
                created_new_topic: false,
              ),
            ).to eq(true)
            expect(
              MovedPost.exists?(
                new_topic: destination_topic,
                new_post_id: p4.id,
                old_topic: topic,
                old_post_id: p4.id,
                created_new_topic: false,
              ),
            ).to eq(true)
          end

          it "moving all posts will close the topic" do
            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to be_closed
          end

          it "doesn't close the topic when not all posts were moved" do
            topic.expects(:add_moderator_post).once
            posts_to_move = [p2.id, p3.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to_not be_closed
          end

          it "doesn't close the topic when all posts except the first one were moved" do
            topic.expects(:add_moderator_post).once
            posts_to_move = [p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to_not be_closed
          end

          it "schedules topic deleting when all posts were moved" do
            SiteSetting.delete_merged_stub_topics_after_days = 7
            freeze_time

            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_present
            expect(timer.execute_at).to eq_time(7.days.from_now)
          end

          it "doesn't schedule topic deleting when not all posts were moved" do
            SiteSetting.delete_merged_stub_topics_after_days = 7

            topic.expects(:add_moderator_post).once
            posts_to_move = [p1.id, p2.id, p3.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_nil
          end

          it "doesn't schedule topic deleting when all posts were moved if it's disabled (-1)" do
            SiteSetting.delete_merged_stub_topics_after_days = -1

            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            expect(Topic.with_deleted.find(topic.id).deleted_at).to be_nil

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_nil
          end

          it "immediately deletes topic when delete_merged_stub_topics_after_days is 0" do
            SiteSetting.delete_merged_stub_topics_after_days = 0
            freeze_time

            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            expect(Topic.with_deleted.find(topic.id).deleted_at).to be_present
          end

          it "ignores moderator posts and closes the topic if all regular posts were moved" do
            add_moderator_post_to topic, Post.types[:moderator_action]
            add_moderator_post_to topic, Post.types[:small_action]

            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            topic.move_posts(user, posts_to_move, destination_topic_id: destination_topic.id)

            topic.reload
            expect(topic).to be_closed
          end

          it "does not try to move small action posts" do
            small_action =
              Fabricate(
                :post,
                topic: topic,
                raw: "A small action",
                post_type: Post.types[:small_action],
              )
            moved_to =
              topic.move_posts(
                user,
                [p1.id, p2.id, p3.id, p4.id, small_action.id],
                destination_topic_id: destination_topic.id,
              )

            moved_to.reload
            expect(moved_to.posts_count).to eq(5)
            expect(small_action.topic_id).to eq(topic.id)

            moderator_post = topic.posts.find_by(post_number: 2)
            expect(moderator_post.raw).to include("4 posts were merged")
          end

          it "updates existing notifications" do
            n3 = Fabricate(:mentioned_notification, post: p3, user: another_user)
            n4 = Fabricate(:mentioned_notification, post: p4, user: another_user)

            moved_to = topic.move_posts(user, [p3.id], destination_topic_id: destination_topic.id)

            n3 = Notification.find(n3.id)
            expect(n3.topic_id).to eq(moved_to.id)
            expect(n3.post_number).to eq(2)
            expect(n3.data_hash[:topic_title]).to eq(moved_to.title)

            n4 = Notification.find(n4.id)
            expect(n4.topic_id).to eq(topic.id)
            expect(n4.post_number).to eq(4)
          end

          it "deletes notifications for users not allowed to see the topic" do
            another_admin = Fabricate(:admin)
            staff_category = Fabricate(:private_category, group: Group[:staff])
            user_notification = Fabricate(:mentioned_notification, post: p3, user: another_user)
            admin_notification = Fabricate(:mentioned_notification, post: p3, user: another_admin)

            destination_topic.update!(category_id: staff_category.id)
            topic.move_posts(user, [p3.id], destination_topic_id: destination_topic.id)

            expect(Notification.exists?(user_notification.id)).to eq(false)
            expect(Notification.exists?(admin_notification.id)).to eq(true)
          end

          context "with post timings" do
            fab!(:some_user) { Fabricate(:user) }

            it "successfully moves timings" do
              create_post_timing(p1, some_user, 500)
              create_post_timing(p2, some_user, 1000)
              create_post_timing(p3, some_user, 1500)
              create_post_timing(p4, some_user, 750)

              moved_to =
                topic.move_posts(user, [p1.id, p4.id], destination_topic_id: destination_topic.id)

              expect(
                PostTiming.where(topic_id: topic.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([1, 500], [2, 1000], [3, 1500])

              expect(
                PostTiming.where(topic_id: moved_to.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([2, 500], [3, 750])
            end

            it "moves timings when post timing exists in destination topic" do
              PostTiming.create!(
                topic_id: destination_topic.id,
                user_id: some_user.id,
                post_number: 2,
                msecs: 800,
              )
              create_post_timing(p1, some_user, 500)

              moved_to = topic.move_posts(user, [p1.id], destination_topic_id: destination_topic.id)

              expect(
                PostTiming.where(topic_id: moved_to.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([2, 500])
            end
          end

          it "updates topic_user.liked values for both source and destination topics" do
            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(false)

            like =
              Fabricate(
                :post_action,
                post: p3,
                user: user,
                post_action_type_id: PostActionType.types[:like],
              )
            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(true)

            expect(TopicUser.find_by(topic: destination_topic, user: user)).to eq(nil)
            topic.move_posts(user, [p3.id], destination_topic_id: destination_topic.id)

            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(false)
            expect(TopicUser.find_by(topic: destination_topic, user: user).liked).to eq(true)
          end

          it "copies the post revisions from first post to the new post" do
            p1.revise(another_user, { raw: "A different raw content" })

            moved_to = topic.move_posts(user, [p1.id], destination_topic_id: destination_topic.id)
            new_post = moved_to.posts.last

            expect(new_post.id).not_to eq(p1.id)
            expect(new_post.version).to eq(2)
            expect(new_post.public_version).to eq(2)
            expect(new_post.post_revisions.size).to eq(1)
          end

          context "with subfolder installs" do
            before { set_subfolder "/forum" }

            it "creates a small action with correct post url" do
              moved_to = topic.move_posts(user, [p2.id], destination_topic_id: destination_topic.id)
              small_action = topic.posts.last

              expect(small_action.post_type).to eq(Post.types[:small_action])

              expected_text =
                I18n.t(
                  "move_posts.existing_topic_moderator_post",
                  count: 1,
                  topic_link: "[#{moved_to.title}](#{p2.reload.relative_url})",
                  locale: :en,
                )

              expect(small_action.raw).to eq(expected_text)
            end
          end

          context "with read state and other stats per user" do
            def create_topic_user(user, topic, opts = {})
              notification_level = opts.delete(:notification_level) || :regular

              Fabricate(
                :topic_user,
                opts.merge(
                  notification_level: TopicUser.notification_levels[notification_level],
                  topic: topic,
                  user: user,
                ),
              )
            end

            fab!(:user1) { Fabricate(:user) }
            fab!(:user2) { Fabricate(:user) }
            fab!(:user3) { Fabricate(:user) }
            fab!(:admin1) { Fabricate(:admin) }
            fab!(:admin2) { Fabricate(:admin) }

            it "leaves post numbers unchanged when they were lower then the topic's highest post number" do
              Fabricate(:post, topic: destination_topic)
              Fabricate(:whisper, topic: destination_topic)

              destination_topic.reload
              expect(destination_topic.highest_post_number).to eq(2)
              expect(destination_topic.highest_staff_post_number).to eq(3)

              create_topic_user(user1, topic, last_read_post_number: 3, last_emailed_post_number: 3)
              create_topic_user(
                user1,
                destination_topic,
                last_read_post_number: 1,
                last_emailed_post_number: 1,
              )

              create_topic_user(user2, topic, last_read_post_number: 3, last_emailed_post_number: 3)
              create_topic_user(
                user2,
                destination_topic,
                last_read_post_number: 2,
                last_emailed_post_number: 2,
              )

              create_topic_user(
                admin1,
                topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )
              create_topic_user(
                admin1,
                destination_topic,
                last_read_post_number: 2,
                last_emailed_post_number: 1,
              )

              create_topic_user(
                admin2,
                topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )
              create_topic_user(
                admin2,
                destination_topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )

              moved_to_topic =
                topic.move_posts(user, [p1.id, p2.id], destination_topic_id: destination_topic.id)

              expect(TopicUser.find_by(topic: moved_to_topic, user: user1)).to have_attributes(
                last_read_post_number: 1,
                last_emailed_post_number: 1,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: user2)).to have_attributes(
                last_read_post_number: 5,
                last_emailed_post_number: 5,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: admin1)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 1,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: admin2)).to have_attributes(
                last_read_post_number: 5,
                last_emailed_post_number: 5,
              )
            end

            it "correctly updates existing topic_user records" do
              destination_topic.update!(created_at: 1.day.ago)

              original_topic_user1 =
                create_topic_user(
                  user1,
                  topic,
                  last_read_post_number: 5,
                  first_visited_at: 5.hours.ago,
                  last_visited_at: 30.minutes.ago,
                  notification_level: :tracking,
                ).reload
              destination_topic_user1 =
                create_topic_user(
                  user1,
                  destination_topic,
                  last_read_post_number: 5,
                  first_visited_at: 7.hours.ago,
                  last_visited_at: 2.hours.ago,
                  notification_level: :watching,
                ).reload

              original_topic_user2 =
                create_topic_user(
                  user2,
                  topic,
                  last_read_post_number: 5,
                  first_visited_at: 3.hours.ago,
                  last_visited_at: 1.hour.ago,
                  notification_level: :watching,
                ).reload
              destination_topic_user2 =
                create_topic_user(
                  user2,
                  destination_topic,
                  last_read_post_number: 5,
                  first_visited_at: 2.hours.ago,
                  last_visited_at: 1.hour.ago,
                  notification_level: :tracking,
                ).reload

              new_topic =
                topic.move_posts(user, [p1.id, p2.id], destination_topic_id: destination_topic.id)

              expect(TopicUser.find_by(topic: new_topic, user: user)).to have_attributes(
                notification_level: TopicUser.notification_levels[:tracking],
                posted: true,
              )

              expect(TopicUser.find_by(topic: new_topic, user: user1)).to have_attributes(
                first_visited_at: destination_topic_user1.first_visited_at,
                last_visited_at: original_topic_user1.last_visited_at,
                notification_level: destination_topic_user1.notification_level,
                posted: false,
              )

              expect(TopicUser.find_by(topic: new_topic, user: user2)).to have_attributes(
                first_visited_at: original_topic_user2.first_visited_at,
                last_visited_at: destination_topic_user2.last_visited_at,
                notification_level: destination_topic_user2.notification_level,
                posted: false,
              )
            end
          end
        end

        context "when moved to a message" do
          it "works correctly" do
            topic.expects(:add_moderator_post).once
            new_topic =
              topic.move_posts(
                user,
                [p2.id, p4.id],
                title: "new testing topic name",
                archetype: "private_message",
              )

            expect(
              TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number,
            ).to eq(p3.post_number)

            expect(new_topic).to be_present
            expect(new_topic.featured_user1_id).to eq(p4.user_id)
            expect(new_topic.like_count).to eq(1)

            expect(new_topic.archetype).to eq(Archetype.private_message)
            expect(topic.featured_user1_id).to be_blank
            expect(new_topic.posts.by_post_number).to match_array([p2, p4])

            new_topic.reload
            expect(new_topic.posts_count).to eq(2)
            expect(new_topic.highest_post_number).to eq(2)

            p4.reload
            expect(new_topic.last_post_user_id).to eq(p4.user_id)
            expect(new_topic.last_posted_at).to eq_time(p4.created_at)
            expect(new_topic.bumped_at).to eq_time(Time.zone.now)

            p2.reload
            expect(p2.sort_order).to eq(1)
            expect(p2.post_number).to eq(1)
            expect(p2.topic_links.first.topic_id).to eq(new_topic.id)

            expect(p4.post_number).to eq(2)
            expect(p4.sort_order).to eq(2)

            topic.reload
            expect(topic.featured_user1_id).to be_blank
            expect(topic.like_count).to eq(0)
            expect(topic.posts_count).to eq(2)
            expect(topic.posts.by_post_number).to match_array([p1, p3])
            expect(topic.highest_post_number).to eq(p3.post_number)

            # both the like and was_liked user actions should be correct
            action = UserAction.find_by(user_id: another_user.id)
            expect(action.target_topic_id).to eq(new_topic.id)

            expect(
              TopicUser.exists?(
                user_id: another_user,
                topic_id: new_topic.id,
                notification_level: TopicUser.notification_levels[:watching],
                notifications_reason_id: TopicUser.notification_reasons[:created_topic],
              ),
            ).to eq(true)
            expect(
              TopicUser.exists?(
                user_id: user,
                topic_id: new_topic.id,
                notification_level: TopicUser.notification_levels[:watching],
                notifications_reason_id: TopicUser.notification_reasons[:created_post],
              ),
            ).to eq(true)
          end
        end

        shared_examples "moves email related stuff" do
          it "moves incoming email" do
            Fabricate(:incoming_email, user: old_post.user, topic: old_post.topic, post: old_post)

            new_topic = topic.move_posts(user, [old_post.id], title: "new testing topic name")
            new_post = new_topic.first_post
            email = new_post.incoming_email

            expect(email).to be_present
            expect(email.topic_id).to eq(new_topic.id)
            expect(email.post_id).to eq(new_post.id)

            unless old_post.id == new_post.id
              expect(old_post.reload.incoming_email).to_not be_present
            end
          end

          it "moves email log entries" do
            old_topic = old_post.topic

            2.times do
              Fabricate(:email_log, user: old_post.user, post: old_post, email_type: :mailing_list)
            end

            some_post = Fabricate(:post)

            Fabricate(:email_log, user: some_post.user, post: some_post, email_type: :mailing_list)

            expect(EmailLog.where(post_id: old_post.id).count).to eq(2)

            new_topic = old_topic.move_posts(user, [old_post.id], title: "new testing topic name")

            new_post = new_topic.first_post

            expect(EmailLog.where(post_id: new_post.id).count).to eq(2)
          end

          it "preserves post attributes" do
            old_post.update_columns(
              cook_method: Post.cook_methods[:email],
              via_email: true,
              raw_email: "raw email content",
            )

            new_topic =
              old_post.topic.move_posts(user, [old_post.id], title: "new testing topic name")
            new_post = new_topic.first_post

            expect(new_post.cook_method).to eq(Post.cook_methods[:email])
            expect(new_post.via_email).to eq(true)
            expect(new_post.raw_email).to eq("raw email content")
          end
        end

        context "when moving the first post" do
          it "copies the OP, doesn't delete it" do
            topic.expects(:add_moderator_post).once
            new_topic = topic.move_posts(user, [p1.id, p2.id], title: "new testing topic name")

            expect(new_topic).to be_present
            expect(new_topic.posts.by_post_number.first.raw).to eq(p1.raw)
            expect(new_topic.posts_count).to eq(2)
            expect(new_topic.highest_post_number).to eq(2)

            # First post didn't move
            p1.reload
            expect(p1.sort_order).to eq(1)
            expect(p1.post_number).to eq(1)
            expect(p1.topic_id).to eq(topic.id)
            expect(p1.reply_count).to eq(1)

            # New first post
            new_first = new_topic.posts.where(post_number: 1).first
            expect(new_first.reply_count).to eq(1)
            expect(new_first.created_at).to eq_time(p1.created_at)

            # Second post is in a new topic
            p2.reload
            expect(p2.post_number).to eq(2)
            expect(p2.sort_order).to eq(2)
            expect(p2.topic_id).to eq(new_topic.id)
            expect(p2.reply_to_post_number).to eq(1)
            expect(p2.reply_count).to eq(0)

            topic.reload
            expect(topic.posts.by_post_number).to match_array([p1, p3, p4])
            expect(topic.highest_post_number).to eq(p4.post_number)

            # updates replies for posts moved to same topic
            expect(PostReply.where(reply_post_id: p2.id).pluck(:post_id)).to contain_exactly(
              new_first.id,
            )

            # leaves replies to the first post of the original topic unchanged
            expect(PostReply.where(reply_post_id: p3.id).pluck(:post_id)).to contain_exactly(p1.id)
          end

          it "preserves post actions in the new post" do
            PostActionCreator.like(another_user, p1)

            new_topic = topic.move_posts(user, [p1.id], title: "new testing topic name")
            new_post = new_topic.posts.where(post_number: 1).first

            expect(new_topic.like_count).to eq(1)
            expect(new_post.like_count).to eq(1)
            expect(new_post.post_actions.size).to eq(1)
          end

          it "preserves the custom_fields in the new post" do
            custom_fields = { "some_field" => "payload" }
            p1.custom_fields = custom_fields
            p1.save_custom_fields

            new_topic = topic.move_posts(user, [p1.id], title: "new testing topic name")

            expect(new_topic.first_post.custom_fields).to eq(custom_fields)
          end

          it "preserves the post revisions in the new post" do
            p1.revise(another_user, { raw: "A different raw content" })

            new_topic = topic.move_posts(user, [p1.id], title: "new testing topic name")
            new_post = new_topic.posts.where(post_number: 1).first

            expect(new_post.id).not_to eq(p1.id)
            expect(new_post.version).to eq(2)
            expect(new_post.public_version).to eq(2)
            expect(new_post.post_revisions.size).to eq(1)
          end

          include_examples "moves email related stuff" do
            let!(:old_post) { p1 }
          end
        end

        context "when moving replies" do
          include_examples "moves email related stuff" do
            let!(:old_post) { p3 }
          end
        end

        context "when moving to an existing topic with a deleted post" do
          before { topic.expects(:add_moderator_post) }

          fab!(:destination_topic) { Fabricate(:topic, user: user) }
          fab!(:destination_op) { Fabricate(:post, topic: destination_topic, user: user) }
          fab!(:destination_deleted_reply) do
            Fabricate(:post, topic: destination_topic, user: another_user)
          end
          let(:moved_to) do
            topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id)
          end

          it "works correctly" do
            destination_deleted_reply.trash!

            expect(moved_to).to eq(destination_topic)

            # Check out new topic
            moved_to.reload
            expect(moved_to.posts_count).to eq(3)
            expect(moved_to.highest_post_number).to eq(4)

            # Posts should be re-ordered
            p2.reload
            expect(p2.sort_order).to eq(3)
            expect(p2.post_number).to eq(3)
            expect(p2.topic_id).to eq(moved_to.id)
            expect(p2.reply_count).to eq(1)
            expect(p2.reply_to_post_number).to eq(nil)

            p4.reload
            expect(p4.post_number).to eq(4)
            expect(p4.sort_order).to eq(4)
            expect(p4.topic_id).to eq(moved_to.id)
            expect(p4.reply_to_post_number).to eq(p2.post_number)
          end
        end

        context "when moving to an existing closed topic" do
          fab!(:destination_topic) { Fabricate(:topic, closed: true) }

          it "works correctly for admin" do
            moved_to =
              topic.move_posts(admin, [p1.id, p2.id], destination_topic_id: destination_topic.id)
            expect(moved_to).to be_present

            moved_to.reload
            expect(moved_to.posts_count).to eq(2)
            expect(moved_to.highest_post_number).to eq(2)
          end
        end

        context "when moving chronologically to an existing topic" do
          fab!(:destination_topic) { Fabricate(:topic, user: user) }
          fab!(:destination_op) do
            Fabricate(
              :post,
              topic: destination_topic,
              user: user,
              created_at: p2.created_at + 30.minutes,
            )
          end

          it "works correctly with post_number gap in destination" do
            destination_p6 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p3.created_at + 5.minutes,
                post_number: 6,
                reply_count: 1,
              )
            destination_p7 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p3.created_at + 10.minutes,
                reply_to_post_number: destination_p6.post_number,
              )
            destination_p6.replies << destination_p7

            # after: p2(-2h) destination_op p3(-1h) destination_p6 destination_p7 p4(-45min)

            topic.expects(:add_moderator_post).once
            moved_to =
              topic.move_posts(
                user,
                [p2.id, p3.id, p4.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to eq(destination_topic)

            # Check out destination topic
            moved_to.reload
            expect(moved_to.posts_count).to eq(6)
            expect(moved_to.highest_post_number).to eq(8)
            expect(moved_to.user_id).to eq(p2.user_id)
            expect(moved_to.like_count).to eq(1)
            expect(moved_to.category_id).to eq(SiteSetting.uncategorized_category_id)
            p4.reload
            expect(moved_to.last_post_user_id).to eq(p4.user_id)
            expect(moved_to.last_posted_at).to eq_time(p4.created_at)

            # Posts should be re-ordered
            p2.reload
            expect(p2.sort_order).to eq(1)
            expect(p2.post_number).to eq(1)
            expect(p2.topic_id).to eq(moved_to.id)
            expect(p2.reply_count).to eq(1)
            expect(p2.reply_to_post_number).to eq(nil)

            destination_op.reload
            expect(destination_op.sort_order).to eq(2)
            expect(destination_op.post_number).to eq(2)
            expect(destination_op.reply_count).to eq(0)
            expect(destination_op.reply_to_post_number).to eq(nil)

            p3.reload
            expect(p3.post_number).to eq(3)
            expect(p3.sort_order).to eq(3)
            expect(p3.topic_id).to eq(moved_to.id)
            expect(p3.reply_count).to eq(0)
            expect(p3.reply_to_post_number).to eq(nil)

            destination_p6.reload
            expect(destination_p6.post_number).to eq(6)
            expect(destination_p6.sort_order).to eq(6)
            expect(destination_p6.reply_count).to eq(1)
            expect(destination_p6.reply_to_post_number).to eq(nil)

            destination_p7.reload
            expect(destination_p7.post_number).to eq(7)
            expect(destination_p7.sort_order).to eq(7)
            expect(destination_p7.reply_count).to eq(0)
            expect(destination_p7.reply_to_post_number).to eq(6)

            p4.reload
            expect(p4.post_number).to eq(8)
            expect(p4.sort_order).to eq(8)
            expect(p4.topic_id).to eq(moved_to.id)
            expect(p4.reply_count).to eq(0)
            expect(p4.reply_to_post_number).to eq(1)

            # Check out the original topic
            topic.reload
            expect(topic.posts_count).to eq(1)
            expect(topic.featured_user1_id).to be_blank
            expect(topic.like_count).to eq(0)
            expect(topic.posts.by_post_number).to match_array([p1])
            expect(topic.highest_post_number).to eq(p1.post_number)

            # Should notify correctly
            notification =
              p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

            expect(notification.topic_id).to eq(destination_topic.id)
            expect(notification.post_number).to eq(p2.post_number)

            # Should update last reads
            expect(
              TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number,
            ).to eq(p1.post_number)
          end

          it "works correctly keeping replies in destination" do
            destination_p2 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p3.created_at - 10.minutes,
                post_number: 2,
                reply_count: 1,
              )
            destination_p3 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p4.created_at + 5.minutes,
                reply_to_post_number: destination_p2.post_number,
                reply_count: 1,
              )
            destination_p4 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p4.created_at + 10.minutes,
                reply_to_post_number: destination_p3.post_number,
              )
            destination_p2.replies << destination_p3
            destination_p3.replies << destination_p4

            # after: destination_op destination_p2 p3(-1h) p4(-45min) destination_p3 destination_p4

            topic.expects(:add_moderator_post).once
            moved_to =
              topic.move_posts(
                user,
                [p3.id, p4.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to eq(destination_topic)

            # Check out destination topic
            moved_to.reload
            expect(moved_to.posts_count).to eq(6)
            expect(moved_to.highest_post_number).to eq(6)
            expect(moved_to.user_id).to eq(destination_op.user_id)
            expect(moved_to.like_count).to eq(1)
            expect(moved_to.category_id).to eq(SiteSetting.uncategorized_category_id)

            # Posts should be re-ordered
            destination_op.reload
            expect(destination_op.sort_order).to eq(1)
            expect(destination_op.post_number).to eq(1)

            destination_p2.reload
            expect(destination_p2.post_number).to eq(2)
            expect(destination_p2.sort_order).to eq(2)
            expect(destination_p2.reply_count).to eq(1)
            expect(destination_p2.reply_to_post_number).to eq(nil)

            p3.reload
            expect(p3.post_number).to eq(3)
            expect(p3.sort_order).to eq(3)
            expect(p3.topic_id).to eq(moved_to.id)
            expect(p3.reply_count).to eq(0)
            expect(p3.reply_to_post_number).to eq(nil)

            p4.reload
            expect(p4.post_number).to eq(4)
            expect(p4.sort_order).to eq(4)
            expect(p4.topic_id).to eq(moved_to.id)
            expect(p4.reply_count).to eq(0)
            expect(p4.reply_to_post_number).to eq(nil)

            destination_p3.reload
            expect(destination_p3.post_number).to eq(5)
            expect(destination_p3.sort_order).to eq(5)
            expect(destination_p3.reply_count).to eq(1)
            expect(destination_p3.reply_to_post_number).to eq(destination_p2.post_number)

            destination_p4.reload
            expect(destination_p4.post_number).to eq(6)
            expect(destination_p4.sort_order).to eq(6)
            expect(destination_p4.reply_count).to eq(0)
            expect(destination_p4.reply_to_post_number).to eq(destination_p3.post_number)

            # Check out the original topic
            topic.reload
            expect(topic.posts_count).to eq(2)
            expect(topic.featured_user1_id).to eq(p2.user_id)
            expect(topic.like_count).to eq(0)
            expect(topic.posts.by_post_number).to match_array([p1, p2])
            expect(topic.highest_post_number).to eq(p2.post_number)

            # Should update last reads
            expect(
              TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number,
            ).to eq(p2.post_number)
          end

          it "works correctly when moving the first post" do
            # forcing a different user_id than p1.user_id
            destination_topic.update_column(:user_id, another_user.id)
            destination_op.update_column(:user_id, another_user.id)

            # after: p1(-3h) destination_op

            topic.expects(:add_moderator_post).once
            moved_to =
              topic.move_posts(
                user,
                [p1.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to eq(destination_topic)

            # Check out destination topic
            moved_to.reload
            expect(moved_to.posts_count).to eq(2)
            expect(moved_to.highest_post_number).to eq(2)
            expect(moved_to.user_id).to eq(p1.user_id)
            expect(moved_to.like_count).to eq(0)

            # First post didn't move
            p1.reload
            expect(p1.sort_order).to eq(1)
            expect(p1.post_number).to eq(1)
            expect(p1.topic_id).to eq(topic.id)
            expect(p1.reply_count).to eq(2)

            # New first post
            new_first = moved_to.posts.where(post_number: 1).first
            expect(new_first.sort_order).to eq(1)
            expect(new_first.reply_count).to eq(0)
            expect(new_first.created_at).to eq_time(p1.created_at)

            destination_op.reload
            expect(destination_op.sort_order).to eq(2)
            expect(destination_op.post_number).to eq(2)

            # Check out the original topic
            topic.reload
            expect(topic.posts_count).to eq(4)
            expect(topic.featured_user1_id).to eq(p2.user_id)
            expect(topic.like_count).to eq(1)
            expect(topic.posts.by_post_number).to match_array([p1, p2, p3, p4])
            expect(topic.highest_post_number).to eq(p4.post_number)
          end

          it "correctly remaps quotes for shifted posts on destination topic" do
            destination_p8 =
              Fabricate(
                :post,
                topic: destination_topic,
                user: another_user,
                created_at: p6.created_at + 10.minutes,
              )

            raw = <<~RAW
            [quote="dan, post:#{destination_p8.post_number}, topic:#{destination_p8.topic_id}, full:true"]
            some quote from the other post
            [/quote]

            the quote above should be updated with new post number and topic id
            RAW

            p3.update!(raw: raw)
            p3.rebake!

            expect {
              topic.move_posts(
                user,
                [p6.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            }.to change { p6.reload.topic_id }.and change {
                    destination_p8.reload.post_number
                  }.and change { p3.reload.raw }.and change { p3.baked_version }.to(nil)

            expect(p3.raw).to include(
              "post:#{destination_p8.post_number}, topic:#{destination_p8.topic_id}",
            )
          end

          it "moving all posts will close the topic" do
            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to be_closed
          end

          it "doesn't close the topic when not all posts were moved" do
            topic.expects(:add_moderator_post).once
            posts_to_move = [p2.id, p3.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to_not be_closed
          end

          it "doesn't close the topic when all posts except the first one were moved" do
            topic.expects(:add_moderator_post).once
            posts_to_move = [p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            topic.reload
            expect(topic).to_not be_closed
          end

          it "schedules topic deleting when all posts were moved" do
            SiteSetting.delete_merged_stub_topics_after_days = 7
            freeze_time

            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_present
            expect(timer.execute_at).to eq_time(7.days.from_now)
          end

          it "doesn't schedule topic deleting when not all posts were moved" do
            SiteSetting.delete_merged_stub_topics_after_days = 7

            topic.expects(:add_moderator_post).once
            posts_to_move = [p1.id, p2.id, p3.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_nil
          end

          it "doesn't schedule topic deleting when all posts were moved if it's disabled in settings" do
            SiteSetting.delete_merged_stub_topics_after_days = 0

            topic.expects(:add_moderator_post).twice
            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            moved_to =
              topic.move_posts(
                user,
                posts_to_move,
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )
            expect(moved_to).to be_present

            timer = topic.topic_timers.find_by(status_type: TopicTimer.types[:delete])
            expect(timer).to be_nil
          end

          it "ignores moderator posts and closes the topic if all regular posts were moved" do
            add_moderator_post_to topic, Post.types[:moderator_action]
            add_moderator_post_to topic, Post.types[:small_action]

            posts_to_move = [p1.id, p2.id, p3.id, p4.id]
            topic.move_posts(
              user,
              posts_to_move,
              destination_topic_id: destination_topic.id,
              chronological_order: true,
            )

            topic.reload
            expect(topic).to be_closed
          end

          it "does not try to move small action posts" do
            small_action =
              Fabricate(
                :post,
                topic: topic,
                raw: "A small action",
                post_type: Post.types[:small_action],
              )
            moved_to =
              topic.move_posts(
                user,
                [p1.id, p2.id, p3.id, p4.id, small_action.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )

            moved_to.reload
            expect(moved_to.posts_count).to eq(5)
            expect(small_action.topic_id).to eq(topic.id)

            moderator_post = topic.posts.find_by(post_number: 2)
            expect(moderator_post.raw).to include("4 posts were merged")
          end

          it "updates existing notifications" do
            n2 = Fabricate(:mentioned_notification, post: p2, user: another_user)
            n4 = Fabricate(:mentioned_notification, post: p4, user: another_user)
            dest_nop = Fabricate(:mentioned_notification, post: destination_op, user: another_user)

            moved_to =
              topic.move_posts(
                user,
                [p2.id],
                destination_topic_id: destination_topic.id,
                chronological_order: true,
              )

            n2 = Notification.find(n2.id)
            expect(n2.topic_id).to eq(moved_to.id)
            expect(n2.post_number).to eq(1)
            expect(n2.data_hash[:topic_title]).to eq(moved_to.title)

            n4 = Notification.find(n4.id)
            expect(n4.topic_id).to eq(topic.id)
            expect(n4.post_number).to eq(4)

            dest_nop = Notification.find(dest_nop.id)
            expect(dest_nop.post_number).to eq(2)
          end

          it "deletes notifications for users not allowed to see the topic" do
            another_admin = Fabricate(:admin)
            staff_category = Fabricate(:private_category, group: Group[:staff])
            user_notification = Fabricate(:mentioned_notification, post: p3, user: another_user)
            admin_notification = Fabricate(:mentioned_notification, post: p3, user: another_admin)

            destination_topic.update!(category_id: staff_category.id)
            topic.move_posts(
              user,
              [p3.id],
              destination_topic_id: destination_topic.id,
              chronological_order: true,
            )

            expect(Notification.exists?(user_notification.id)).to eq(false)
            expect(Notification.exists?(admin_notification.id)).to eq(true)
          end

          context "with post timings" do
            fab!(:some_user) { Fabricate(:user) }

            it "successfully moves timings" do
              create_post_timing(p1, some_user, 500)
              create_post_timing(p2, some_user, 1000)
              create_post_timing(p3, some_user, 1500)
              create_post_timing(p4, some_user, 750)

              moved_to =
                topic.move_posts(
                  user,
                  [p1.id, p4.id],
                  destination_topic_id: destination_topic.id,
                  chronological_order: true,
                )

              expect(
                PostTiming.where(topic_id: topic.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([1, 500], [2, 1000], [3, 1500])

              expect(
                PostTiming.where(topic_id: moved_to.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([1, 500], [3, 750])
            end

            it "moves timings when post timing exists in destination topic" do
              destination_p2 =
                Fabricate(
                  :post,
                  topic: destination_topic,
                  user: another_user,
                  created_at: destination_op.created_at + 10.minutes,
                  post_number: 2,
                )
              destination_p3 =
                Fabricate(
                  :post,
                  topic: destination_topic,
                  user: another_user,
                  created_at: destination_op.created_at + 15.minutes,
                  post_number: 3,
                )
              destination_topic.update!(highest_post_number: 3)

              PostTiming.create!(
                topic_id: destination_topic.id,
                user_id: some_user.id,
                post_number: 4,
                msecs: 800,
              )
              create_post_timing(destination_op, some_user, 1500)
              create_post_timing(destination_p2, some_user, 2000)
              create_post_timing(destination_p3, some_user, 1250)
              create_post_timing(p1, some_user, 500)

              moved_to =
                topic.move_posts(
                  user,
                  [p1.id],
                  destination_topic_id: destination_topic.id,
                  chronological_order: true,
                )

              expect(
                PostTiming.where(topic_id: moved_to.id, user_id: some_user.id).pluck(
                  :post_number,
                  :msecs,
                ),
              ).to contain_exactly([1, 500], [2, 1500], [3, 2000], [4, 1250])
            end
          end

          it "updates topic_user.liked values for both source and destination topics" do
            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(false)

            like =
              Fabricate(
                :post_action,
                post: p3,
                user: user,
                post_action_type_id: PostActionType.types[:like],
              )
            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(true)

            expect(TopicUser.find_by(topic: destination_topic, user: user)).to eq(nil)
            topic.move_posts(
              user,
              [p3.id],
              destination_topic_id: destination_topic.id,
              chronological_order: true,
            )

            expect(TopicUser.find_by(topic: topic, user: user).liked).to eq(false)
            expect(TopicUser.find_by(topic: destination_topic, user: user).liked).to eq(true)
          end

          context "with read state and other stats per user" do
            def create_topic_user(user, topic, opts = {})
              notification_level = opts.delete(:notification_level) || :regular

              Fabricate(
                :topic_user,
                opts.merge(
                  notification_level: TopicUser.notification_levels[notification_level],
                  topic: topic,
                  user: user,
                ),
              )
            end

            fab!(:user1) { Fabricate(:user) }
            fab!(:user2) { Fabricate(:user) }
            fab!(:user3) { Fabricate(:user) }
            fab!(:admin1) { Fabricate(:admin) }
            fab!(:admin2) { Fabricate(:admin) }

            it "leaves post numbers unchanged when they were lower then the topic's highest post number" do
              Fabricate(:post, topic: destination_topic)
              Fabricate(:whisper, topic: destination_topic)

              destination_topic.reload
              expect(destination_topic.highest_post_number).to eq(2)
              expect(destination_topic.highest_staff_post_number).to eq(3)

              create_topic_user(user1, topic, last_read_post_number: 3, last_emailed_post_number: 3)
              create_topic_user(
                user1,
                destination_topic,
                last_read_post_number: 1,
                last_emailed_post_number: 1,
              )

              create_topic_user(user2, topic, last_read_post_number: 3, last_emailed_post_number: 3)
              create_topic_user(
                user2,
                destination_topic,
                last_read_post_number: 2,
                last_emailed_post_number: 2,
              )

              create_topic_user(
                admin1,
                topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )
              create_topic_user(
                admin1,
                destination_topic,
                last_read_post_number: 2,
                last_emailed_post_number: 1,
              )

              create_topic_user(
                admin2,
                topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )
              create_topic_user(
                admin2,
                destination_topic,
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )

              moved_to_topic =
                topic.move_posts(
                  user,
                  [p1.id, p2.id],
                  destination_topic_id: destination_topic.id,
                  chronological_order: true,
                )

              expect(TopicUser.find_by(topic: moved_to_topic, user: user1)).to have_attributes(
                last_read_post_number: 1,
                last_emailed_post_number: 1,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: user2)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 2,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: admin1)).to have_attributes(
                last_read_post_number: 2,
                last_emailed_post_number: 1,
              )

              expect(TopicUser.find_by(topic: moved_to_topic, user: admin2)).to have_attributes(
                last_read_post_number: 3,
                last_emailed_post_number: 3,
              )
            end

            it "correctly updates existing topic_user records" do
              destination_topic.update!(created_at: 1.day.ago)

              original_topic_user1 =
                create_topic_user(
                  user1,
                  topic,
                  last_read_post_number: 5,
                  first_visited_at: 5.hours.ago,
                  last_visited_at: 30.minutes.ago,
                  notification_level: :tracking,
                ).reload
              destination_topic_user1 =
                create_topic_user(
                  user1,
                  destination_topic,
                  last_read_post_number: 5,
                  first_visited_at: 7.hours.ago,
                  last_visited_at: 2.hours.ago,
                  notification_level: :watching,
                ).reload

              original_topic_user2 =
                create_topic_user(
                  user2,
                  topic,
                  last_read_post_number: 5,
                  first_visited_at: 3.hours.ago,
                  last_visited_at: 1.hour.ago,
                  notification_level: :watching,
                ).reload
              destination_topic_user2 =
                create_topic_user(
                  user2,
                  destination_topic,
                  last_read_post_number: 5,
                  first_visited_at: 2.hours.ago,
                  last_visited_at: 1.hour.ago,
                  notification_level: :tracking,
                ).reload

              new_topic =
                topic.move_posts(
                  user,
                  [p1.id, p2.id],
                  destination_topic_id: destination_topic.id,
                  chronological_order: true,
                )

              expect(TopicUser.find_by(topic: new_topic, user: user)).to have_attributes(
                notification_level: TopicUser.notification_levels[:tracking],
                posted: true,
              )

              expect(TopicUser.find_by(topic: new_topic, user: user1)).to have_attributes(
                first_visited_at: destination_topic_user1.first_visited_at,
                last_visited_at: original_topic_user1.last_visited_at,
                notification_level: destination_topic_user1.notification_level,
                posted: false,
              )

              expect(TopicUser.find_by(topic: new_topic, user: user2)).to have_attributes(
                first_visited_at: original_topic_user2.first_visited_at,
                last_visited_at: destination_topic_user2.last_visited_at,
                notification_level: destination_topic_user2.notification_level,
                posted: false,
              )
            end
          end
        end

        it "skips validations when moving posts" do
          p1.update_attribute(:raw, "foo")
          p2.update_attribute(:raw, "bar")

          new_topic = topic.move_posts(user, [p1.id, p2.id], title: "new testing topic name")

          expect(new_topic).to be_present
          expect(new_topic.posts.by_post_number.first.raw).to eq(p1.raw)
          expect(new_topic.posts.by_post_number.last.raw).to eq(p2.raw)
          expect(new_topic.posts_count).to eq(2)
        end

        it "corrects reply_counts within original topic" do
          expect do
            topic.move_posts(user, [p4.id], title: "new testing topic name 1")
          end.to change { PostReply.count }.by(-1)
          expect(p1.reload.reply_count).to eq(2)
          expect(p2.reload.reply_count).to eq(0)

          expect do
            topic.move_posts(user, [p2.id, p3.id], title: "new testing topic name 2")
          end.to change { PostReply.count }.by(-2)
          expect(p1.reload.reply_count).to eq(0)
        end
      end
    end

    context "with messages" do
      fab!(:user)
      fab!(:another_user) { Fabricate(:user) }
      fab!(:regular_user) { Fabricate(:trust_level_4) }
      fab!(:personal_message) { Fabricate(:private_message_topic, user: evil_trout) }
      fab!(:p1) { Fabricate(:post, topic: personal_message, user: user, created_at: 4.hours.ago) }
      fab!(:p2) do
        Fabricate(
          :post,
          topic: personal_message,
          reply_to_post_number: p1.post_number,
          user: another_user,
          created_at: 3.hours.ago,
        )
      end
      fab!(:p3) do
        Fabricate(
          :post,
          topic: personal_message,
          reply_to_post_number: p1.post_number,
          user: user,
          created_at: 2.hours.ago,
        )
      end
      fab!(:p4) do
        Fabricate(
          :post,
          topic: personal_message,
          reply_to_post_number: p2.post_number,
          user: user,
          created_at: 1.hour.ago,
        )
      end
      fab!(:p5) do
        Fabricate(:post, topic: personal_message, user: evil_trout, created_at: 30.minutes.ago)
      end
      let(:another_personal_message) do
        Fabricate(
          :private_message_topic,
          user: user,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end
      let!(:p6) { Fabricate(:post, topic: another_personal_message, user: evil_trout) }

      before do
        SiteSetting.tagging_enabled = true
        Jobs.run_immediately!
        p1.replies << p3
        p2.replies << p4
        UserActionManager.enable
        @like = PostActionCreator.like(another_user, p4)
      end

      context "when moving to new message" do
        it "adds post users as topic allowed users" do
          TopicUser.change(
            user,
            personal_message,
            notification_level: TopicUser.notification_levels[:muted],
          )
          TopicUser.change(
            another_user,
            personal_message,
            notification_level: TopicUser.notification_levels[:tracking],
          )

          personal_message.move_posts(
            admin,
            [p2.id, p3.id, p4.id, p5.id],
            title: "new testing message name",
            tags: %w[tag1 tag2],
            archetype: "private_message",
          )

          p2.reload
          destination_topic = p2.topic
          expect(destination_topic.archetype).to eq(Archetype.private_message)
          expect(destination_topic.topic_allowed_users.where(user_id: user.id).count).to eq(1)
          expect(destination_topic.topic_allowed_users.where(user_id: another_user.id).count).to eq(
            1,
          )
          expect(destination_topic.topic_allowed_users.where(user_id: evil_trout.id).count).to eq(1)
          expect(destination_topic.tags.pluck(:name)).to eq([])
          expect(
            TopicUser.exists?(
              user_id: another_user,
              topic_id: destination_topic.id,
              notification_level: TopicUser.notification_levels[:tracking],
              notifications_reason_id: TopicUser.notification_reasons[:created_topic],
            ),
          ).to eq(true)
          expect(
            TopicUser.exists?(
              user_id: user,
              topic_id: destination_topic.id,
              notification_level: TopicUser.notification_levels[:muted],
              notifications_reason_id: TopicUser.notification_reasons[:created_post],
            ),
          ).to eq(true)
        end

        it "can add tags to new message when staff group is included in pm_tags_allowed_for_groups" do
          SiteSetting.pm_tags_allowed_for_groups = "1|2|3"
          SiteSetting.tag_topic_allowed_groups = "1|2|3"
          personal_message.move_posts(
            admin,
            [p2.id, p5.id],
            title: "new testing message name",
            tags: %w[tag1 tag2],
            archetype: "private_message",
          )

          p2.reload
          expect(p2.topic.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
        end

        it "correctly handles notifications" do
          old_message = p2.topic
          old_message_id = p2.topic_id

          personal_message.move_posts(
            admin,
            [p2.id, p4.id],
            title: "new testing message name",
            archetype: "private_message",
          )

          p2.reload
          expect(p2.topic_id).not_to eq(old_message_id)
          expect(p2.reply_to_post_number).to eq(nil)
          expect(p2.reply_to_user_id).to eq(nil)

          notification =
            p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

          expect(notification.topic_id).to eq(p2.topic_id)
          expect(notification.topic_id).not_to eq(old_message_id)
          expect(notification.post_number).to eq(1)

          # no message for person who made the move
          expect(
            admin.notifications.where(notification_type: Notification.types[:moved_post]).length,
          ).to eq(0)

          old_message.reload
          move_message = old_message.posts.find_by(post_number: 2)
          expect(move_message.post_type).to eq(Post.types[:whisper])
          expect(move_message.raw).to include("2 posts were split")
        end
      end

      context "when moving to existing message" do
        it "adds post users as topic allowed users" do
          personal_message.move_posts(
            admin,
            [p2.id, p5.id],
            destination_topic_id: another_personal_message.id,
            archetype: "private_message",
          )

          p2.reload
          expect(p2.topic_id).to eq(another_personal_message.id)

          another_personal_message.reload
          expect(
            another_personal_message.topic_allowed_users.where(user_id: another_user.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: evil_trout.id).count,
          ).to eq(1)
        end

        it "can add additional participants" do
          personal_message.move_posts(
            admin,
            [p2.id, p5.id],
            destination_topic_id: another_personal_message.id,
            participants: [regular_user.username],
            archetype: "private_message",
          )

          another_personal_message.reload
          expect(
            another_personal_message.topic_allowed_users.where(user_id: another_user.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: evil_trout.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: regular_user.id).count,
          ).to eq(1)
        end

        it "does not allow moving regular topic posts in personal message" do
          topic = Fabricate(:topic, created_at: 4.hours.ago)

          expect {
            personal_message.move_posts(admin, [p2.id, p5.id], destination_topic_id: topic.id)
          }.to raise_error(Discourse::InvalidParameters)
        end

        it "moving all posts will close the message" do
          moved_to =
            personal_message.move_posts(
              admin,
              [p1.id, p2.id, p3.id, p4.id, p5.id],
              destination_topic_id: another_personal_message.id,
              archetype: "private_message",
            )
          expect(moved_to).to be_present

          personal_message.reload
          expect(personal_message.closed).to eq(true)
          expect(moved_to.posts_count).to eq(6)
        end

        it "uses the correct small action post" do
          moved_to =
            personal_message.move_posts(
              admin,
              [p2.id],
              destination_topic_id: another_personal_message.id,
              archetype: "private_message",
            )
          post = Post.find_by(topic_id: personal_message.id, post_type: Post.types[:whisper])

          expected_text =
            I18n.t(
              "move_posts.existing_message_moderator_post",
              count: 1,
              topic_link: "[#{moved_to.title}](#{p2.reload.url})",
              locale: :en,
            )

          expect(post.raw).to eq(expected_text)
        end
      end

      context "when moving chronologically to existing message" do
        it "adds post users as topic allowed users" do
          personal_message.move_posts(
            admin,
            [p2.id, p5.id],
            destination_topic_id: another_personal_message.id,
            archetype: "private_message",
            chronological_order: true,
          )

          p2.reload
          expect(p2.topic_id).to eq(another_personal_message.id)

          another_personal_message.reload
          expect(
            another_personal_message.topic_allowed_users.where(user_id: another_user.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: evil_trout.id).count,
          ).to eq(1)
        end

        it "can add additional participants" do
          personal_message.move_posts(
            admin,
            [p2.id, p5.id],
            destination_topic_id: another_personal_message.id,
            participants: [regular_user.username],
            archetype: "private_message",
            chronological_order: true,
          )

          another_personal_message.reload
          expect(
            another_personal_message.topic_allowed_users.where(user_id: another_user.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: evil_trout.id).count,
          ).to eq(1)
          expect(
            another_personal_message.topic_allowed_users.where(user_id: regular_user.id).count,
          ).to eq(1)
        end

        it "does not allow moving regular topic posts in personal message" do
          topic = Fabricate(:topic, created_at: 4.hours.ago)

          expect {
            personal_message.move_posts(
              admin,
              [p2.id, p5.id],
              destination_topic_id: topic.id,
              chronological_order: true,
            )
          }.to raise_error(Discourse::InvalidParameters)
        end

        it "moving all posts will close the message" do
          moved_to =
            personal_message.move_posts(
              admin,
              [p1.id, p2.id, p3.id, p4.id, p5.id],
              destination_topic_id: another_personal_message.id,
              archetype: "private_message",
              chronological_order: true,
            )
          expect(moved_to).to be_present

          personal_message.reload
          expect(personal_message.closed).to eq(true)
          expect(moved_to.posts_count).to eq(6)
        end

        it "uses the correct small action post" do
          moved_to =
            personal_message.move_posts(
              admin,
              [p2.id],
              destination_topic_id: another_personal_message.id,
              archetype: "private_message",
              chronological_order: true,
            )
          post = Post.find_by(topic_id: personal_message.id, post_type: Post.types[:whisper])

          expected_text =
            I18n.t(
              "move_posts.existing_message_moderator_post",
              count: 1,
              topic_link: "[#{moved_to.title}](#{moved_to.relative_url})",
              locale: :en,
            )

          expect(post.raw).to eq(expected_text)
        end
      end
    end

    context "with banner topic" do
      fab!(:regular_user) { Fabricate(:trust_level_4) }
      fab!(:topic)
      fab!(:personal_message) { Fabricate(:private_message_topic, user: regular_user) }
      fab!(:banner_topic) { Fabricate(:banner_topic, user: evil_trout) }
      fab!(:p1) { Fabricate(:post, topic: banner_topic, user: evil_trout) }
      fab!(:p2) do
        Fabricate(
          :post,
          topic: banner_topic,
          reply_to_post_number: p1.post_number,
          user: regular_user,
        )
      end

      context "when moving to existing topic" do
        it "allows moving banner topic posts in regular topic" do
          banner_topic.move_posts(admin, [p2.id], destination_topic_id: topic.id)
          expect(p2.reload.topic_id).to eq(topic.id)
        end

        it "does not allow moving banner topic posts in personal message" do
          expect {
            banner_topic.move_posts(admin, [p2.id], destination_topic_id: personal_message.id)
          }.to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    context "with event trigger" do
      fab!(:topic_1) { Fabricate(:topic) }
      fab!(:topic_2) { Fabricate(:topic) }
      fab!(:post_1) { Fabricate(:post, topic: topic_1) }
      fab!(:post_2) { Fabricate(:post, topic: topic_1) }

      it "receives 2 post moved event triggers for the first post" do
        post_mover = PostMover.new(topic_1, Discourse.system_user, [post_1.id])
        events = DiscourseEvent.track_events { post_mover.to_topic(topic_2.id) }
        filtered_events =
          events.filter { |e| %i[first_post_moved post_moved].include? e[:event_name] }

        expect(filtered_events.size).to eq(2)
      end

      it "uses first_post_moved trigger for first post" do
        post_mover = PostMover.new(topic_1, Discourse.system_user, [post_1.id])
        events = DiscourseEvent.track_events(:first_post_moved) { post_mover.to_topic(topic_2.id) }
        expect(events.size).to eq(1)

        new_post = Post.find_by(topic_id: topic_2.id, post_number: 1)

        event = events.first
        expect(event[:event_name]).to eq(:first_post_moved)
        expect(event[:params][0]).to eq(new_post)
        expect(event[:params][1]).to eq(post_1)
      end

      it "uses post_moved trigger for other posts" do
        post_mover = PostMover.new(topic_1, Discourse.system_user, [post_2.id])
        events = DiscourseEvent.track_events(:post_moved) { post_mover.to_topic(topic_2.id) }
        expect(events.size).to eq(1)

        event = events.first
        expect(event[:event_name]).to eq(:post_moved)
        expect(event[:params][0]).to eq(post_2)
        expect(event[:params][1]).to eq(topic_1.id)
      end
    end

    context "with modifier" do
      fab!(:topic_1) { Fabricate(:topic) }
      fab!(:topic_2) { Fabricate(:topic) }
      fab!(:post_1) { Fabricate(:post, topic: topic_1) }
      fab!(:user)

      before { SiteSetting.delete_merged_stub_topics_after_days = 0 }
      let(:modifier_block) do
        Proc.new do |is_currently_allowed_to_delete, topic, who_is_merging|
          expect(is_currently_allowed_to_delete).to eq(false)
          expect(topic).to eq(topic_1)
          user.id == who_is_merging.id
        end
      end
      it "lets user merge topics immediately" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:is_allowed_to_delete_after_merge, &modifier_block)
        topic_1.move_posts(user, topic_1.posts.map(&:id), destination_topic_id: topic_2.id)

        expect(topic_1.deleted_at).not_to be_nil
        expect(topic_2.posts.count).to eq(1)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :is_allowed_to_delete_after_merge,
          &modifier_block
        )
      end

      it "allows specific user to merge topics" do
        special_user = Fabricate(:user)
        plugin_instance = Plugin::Instance.new

        plugin_instance.register_modifier(:is_allowed_to_delete_after_merge, &modifier_block)
        topic_1.move_posts(special_user, topic_1.posts.map(&:id), destination_topic_id: topic_2.id)

        expect(topic_1.deleted_at).to be_nil
        topic_1.move_posts(user, topic_1.posts.map(&:id), destination_topic_id: topic_2.id)
        expect(topic_1.deleted_at).not_to be_nil
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :is_allowed_to_delete_after_merge,
          &modifier_block
        )
      end

      it "works fine without modifier" do
        topic_1.move_posts(user, topic_1.posts.map(&:id), destination_topic_id: topic_2.id)

        expect(topic_1.deleted_at).to be_nil

        topic_1.move_posts(admin, topic_1.posts.map(&:id), destination_topic_id: topic_2.id)

        expect(topic_1.deleted_at).not_to be_nil
      end
    end

    context "with freeze_original option" do
      fab!(:original_topic) { Fabricate(:topic) }
      fab!(:destination_topic) { Fabricate(:topic) }
      fab!(:op) { Fabricate(:post, topic: original_topic, raw: "op of this topic") }
      fab!(:op_of_destination) do
        Fabricate(:post, topic: destination_topic, raw: "op of this topic")
      end
      fab!(:first_post) { Fabricate(:post, topic: original_topic, raw: "first_post") }
      fab!(:second_post) { Fabricate(:post, topic: original_topic, raw: "second_post") }
      fab!(:third_post) { Fabricate(:post, topic: original_topic, raw: "third_post") }

      it "keeps a post when moving it to a new topic" do
        new_topic =
          PostMover.new(
            original_topic,
            Discourse.system_user,
            [first_post.id],
            options: {
              freeze_original: true,
            },
          ).to_new_topic("Hi I'm a new topic, with a copy of the old posts")
        expect(new_topic.posts.map(&:raw)).to include(first_post.raw)
        expect(original_topic.posts.map(&:raw)).to include(first_post.raw)
      end

      it "keeps a post when moving to an existing topic" do
        PostMover.new(
          original_topic,
          Discourse.system_user,
          [first_post.id],
          options: {
            freeze_original: true,
          },
        ).to_topic(destination_topic.id)
        expect(destination_topic.posts.map(&:raw)).to include(first_post.raw)
        expect(original_topic.posts.map(&:raw)).to include(first_post.raw)
      end

      it "creates a MovedPost record when moving to an existing topic" do
        PostMover.new(
          original_topic,
          Discourse.system_user,
          [first_post.id],
          options: {
            freeze_original: true,
          },
        ).to_topic(destination_topic.id)
        expect(
          MovedPost.exists?(
            old_topic_id: original_topic.id,
            new_topic_id: destination_topic.id,
            old_post_id: first_post.id,
          ),
        ).to eq(true)
      end

      it "creates the moderator message in the correct position" do
        PostMover.new(
          original_topic,
          Discourse.system_user,
          [first_post.id, second_post.id],
          options: {
            freeze_original: true,
          },
        ).to_topic(destination_topic.id)

        moderator_post =
          original_topic.reload.ordered_posts.find_by(post_number: second_post.post_number + 1) # the next post
        expect(moderator_post).to be_present
        expect(moderator_post.post_type).to eq(Post.types[:small_action])
        expect(moderator_post.action_code).to eq("split_topic")
      end

      it "keeps posts when moving all posts to a new topic" do
        all_posts_from_original_topic = original_topic.ordered_posts.map(&:raw)

        new_topic =
          PostMover.new(
            original_topic,
            Discourse.system_user,
            original_topic.posts.map(&:id),
            options: {
              freeze_original: true,
            },
          ).to_new_topic("Hi I'm a new topic, with a copy of the old posts")

        expect(original_topic.deleted_at).to be_nil
        expect(original_topic.closed?).to eq(true)

        expect(original_topic.posts.map(&:raw)).to include(*all_posts_from_original_topic)
        expect(new_topic.posts.map(&:raw)).to include(*all_posts_from_original_topic)
      end

      it "does not get deleted when moved all posts to topic" do
        SiteSetting.delete_merged_stub_topics_after_days = 0
        all_posts_from_original_topic = original_topic.posts.map(&:raw)

        PostMover.new(
          original_topic,
          Discourse.system_user,
          original_topic.posts.map(&:id),
          options: {
            freeze_original: true,
          },
        ).to_topic(destination_topic.id)

        expect(original_topic.deleted_at).to be_nil
        expect(original_topic.closed?).to eq(true)

        expect(original_topic.posts.map(&:raw)).to include(*all_posts_from_original_topic)
        expect(destination_topic.posts.map(&:raw)).to include(*all_posts_from_original_topic)
      end

      it "keeps all posts when moving to a new PM" do
        moving_posts = [first_post, second_post]
        pm =
          PostMover.new(
            original_topic,
            Discourse.system_user,
            moving_posts.map(&:id),
            move_to_pm: true,
            options: {
              freeze_original: true,
            },
          ).to_new_topic("Hi I'm a new PM, with a copy of the old posts")

        expect(original_topic.posts.map(&:raw)).to include(*moving_posts.map(&:raw))
        expect(pm.posts.map(&:raw)).to include(*moving_posts.map(&:raw))
      end

      it "keep all posts when moving to an existing PM" do
        pm = Fabricate(:private_message_topic)
        pm_with_posts = Fabricate(:private_message_topic)
        moving_posts = [
          Fabricate(:post, topic: pm_with_posts),
          Fabricate(:post, topic: pm_with_posts),
        ]

        PostMover.new(
          pm_with_posts,
          Discourse.system_user,
          moving_posts.map(&:id),
          move_to_pm: true,
          options: {
            freeze_original: true,
          },
        ).to_topic(pm.id)

        expect(pm_with_posts.posts.map(&:raw)).to include(*moving_posts.map(&:raw))
        expect(pm.posts.map(&:raw)).to include(*moving_posts.map(&:raw))
      end

      context "with rate limit" do
        before do
          RateLimiter.enable
          Fabricate.times(20, :post, topic: original_topic)
        end

        it "does not rate limit when moving to a new topic" do
          begin
            PostMover.new(
              original_topic,
              Discourse.system_user,
              original_topic.posts.map(&:id),
              options: {
                freeze_original: true,
              },
            ).to_new_topic("Hi I'm a new topic, with a copy of the old posts")
          rescue RateLimiter::LimitExceeded
            fail "Rate limit exceeded"
          end
        end

        it "does not rate limit when moving to an existing topic" do
          begin
            PostMover.new(
              original_topic,
              Discourse.system_user,
              original_topic.posts.map(&:id),
              options: {
                freeze_original: true,
              },
            ).to_topic(destination_topic.id)
          rescue RateLimiter::LimitExceeded
            fail "Rate limit exceeded"
          end
        end

        it "does not rate limit when moving to a new PM" do
          begin
            PostMover.new(
              original_topic,
              Discourse.system_user,
              original_topic.posts.map(&:id),
              move_to_pm: true,
              options: {
                freeze_original: true,
              },
            ).to_new_topic("Hi I'm a new PM, with a copy of the old posts")
          rescue RateLimiter::LimitExceeded
            fail "Rate limit exceeded"
          end
        end

        it "does not rate limit when moving to an existing PM" do
          begin
            PostMover.new(
              original_topic,
              Discourse.system_user,
              original_topic.posts.map(&:id),
              move_to_pm: true,
              options: {
                freeze_original: true,
              },
            ).to_topic(destination_topic.id)
          rescue RateLimiter::LimitExceeded
            fail "Rate limit exceeded"
          end
        end
      end
    end
  end
end
