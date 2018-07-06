require 'rails_helper'

describe PostMover do

  describe '#move_types' do
    context "verify enum sequence" do
      before do
        @move_types = PostMover.move_types
      end

      it "'new_topic' should be at 1st position" do
        expect(@move_types[:new_topic]).to eq(1)
      end

      it "'existing_topic' should be at 2nd position" do
        expect(@move_types[:existing_topic]).to eq(2)
      end
    end
  end

  context 'move_posts' do
    let(:user) { Fabricate(:user, admin: true) }
    let(:another_user) { Fabricate(:evil_trout) }
    let(:category) { Fabricate(:category, user: user) }
    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:p1) { Fabricate(:post, topic: topic, user: user, created_at: 3.hours.ago) }

    let!(:p2) do
      Fabricate(:post,
        topic: topic,
        user: another_user,
        raw: "Has a link to [evil trout](http://eviltrout.com) which is a cool site.",
        reply_to_post_number: p1.post_number)
    end

    let!(:p3) { Fabricate(:post, topic: topic, reply_to_post_number: p1.post_number, user: user) }
    let!(:p4) { Fabricate(:post, topic: topic, reply_to_post_number: p2.post_number, user: user) }
    let!(:p5) { Fabricate(:post) }
    let(:p6) { Fabricate(:post, topic: topic) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.queue_jobs = false
      p1.replies << p3
      p2.replies << p4
      UserActionCreator.enable
      @like = PostAction.act(another_user, p4, PostActionType.types[:like])
    end

    context 'success' do

      it "correctly handles notifications and bread crumbs" do
        old_topic = p2.topic

        old_topic_id = p2.topic_id

        topic.move_posts(user, [p2.id, p4.id, p6.id], title: "new testing topic name")

        p2.reload
        expect(p2.topic_id).not_to eq(old_topic_id)
        expect(p2.reply_to_post_number).to eq(nil)
        expect(p2.reply_to_user_id).to eq(nil)

        notification = p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

        expect(notification.topic_id).to eq(p2.topic_id)
        expect(notification.post_number).to eq(1)

        # no message for person who made the move
        expect(p4.user.notifications.where(notification_type: Notification.types[:moved_post]).length).to eq(0)

        # notify at the right spot in the stream
        notification = p6.user.notifications.where(notification_type: Notification.types[:moved_post]).first

        expect(notification.topic_id).to eq(p2.topic_id)

        # this is the 3rd post we moved
        expect(notification.post_number).to eq(3)

        old_topic.reload
        move_message = old_topic.posts.find_by(post_number: 2)
        expect(move_message.post_type).to eq(Post.types[:small_action])
        expect(move_message.raw).to include("3 posts were split")
      end

    end

    context "errors" do

      it "raises an error when one of the posts doesn't exist" do
        expect { topic.move_posts(user, [1003], title: "new testing topic name") }.to raise_error(Discourse::InvalidParameters)
      end

      it "raises an error and does not create a topic if no posts were moved" do
        Topic.count.tap do |original_topic_count|
          expect {
            topic.move_posts(user, [], title: "new testing topic name")
          }.to raise_error(Discourse::InvalidParameters)

          expect(Topic.count).to eq original_topic_count
        end
      end
    end

    context "successfully moved" do
      before do
        TopicUser.update_last_read(user, topic.id, p4.post_number, p4.post_number, 0)
        TopicLink.extract_from(p2)
      end

      context "post replies" do
        describe "when a post with replies is moved" do
          it "should update post replies correctly" do
            topic.move_posts(
              user,
              [p2.id],
              title: 'GOT is a very addictive show', category_id: category.id
            )

            expect(p2.reload.replies).to eq([])
          end

          it "doesn't raise errors with deleted replies" do
            p4.trash!
            topic.move_posts(
              user,
              [p2.id],
              title: 'GOT is a very addictive show', category_id: category.id
            )

            expect(p2.reload.replies).to eq([])
          end
        end

        describe "when replies of a post have been moved" do
          it "should update post replies correctly" do
            p5 = Fabricate(
              :post,
              topic: topic,
              reply_to_post_number: p2.post_number,
              user: another_user
            )

            p2.replies << p5

            topic.move_posts(
              user,
              [p4.id],
              title: 'GOT is a very addictive show', category_id: category.id
            )

            expect(p2.reload.replies).to eq([p5])
          end
        end

        describe "when only one reply is left behind" do
          it "should update post replies correctly" do
            p5 = Fabricate(
              :post,
              topic: topic,
              reply_to_post_number: p2.post_number,
              user: another_user
            )

            p2.replies << p5

            topic.move_posts(
              user,
              [p2.id, p4.id],
              title: 'GOT is a very addictive show', category_id: category.id
            )

            expect(p2.reload.replies).to eq([p4])
          end
        end
      end

      context "to a new topic" do

        it "works correctly" do
          topic.expects(:add_moderator_post).once
          new_topic = topic.move_posts(user, [p2.id, p4.id], title: "new testing topic name", category_id: category.id, tags: ["tag1", "tag2"])

          expect(TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number).to eq(p3.post_number)

          expect(new_topic).to be_present
          expect(new_topic.featured_user1_id).to eq(p4.user_id)
          expect(new_topic.like_count).to eq(1)

          expect(new_topic.category).to eq(category)
          expect(new_topic.tags.pluck(:name)).to eq(["tag1", "tag2"])
          expect(topic.featured_user1_id).to be_blank
          expect(new_topic.posts.by_post_number).to match_array([p2, p4])

          new_topic.reload
          expect(new_topic.posts_count).to eq(2)
          expect(new_topic.highest_post_number).to eq(2)

          last_post = new_topic.posts.last
          expect(new_topic.last_post_user_id).to eq(last_post.user_id)
          expect(new_topic.last_posted_at).to eq(last_post.created_at)
          expect(new_topic.bumped_at).to eq(last_post.created_at)

          p2.reload
          expect(p2.sort_order).to eq(1)
          expect(p2.post_number).to eq(1)
          expect(p2.topic_links.first.topic_id).to eq(new_topic.id)

          p4.reload
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
        end

        it "moving all posts will close the topic" do
          topic.expects(:add_moderator_post).twice
          new_topic = topic.move_posts(user, [p1.id, p2.id, p3.id, p4.id], title: "new testing topic name", category_id: category.id)
          expect(new_topic).to be_present

          topic.reload
          expect(topic.closed).to eq(true)
        end

        it 'does not move posts that do not belong to the existing topic' do
          new_topic = topic.move_posts(
            user, [p2.id, p3.id, p5.id], title: 'Logan is a pretty good movie'
          )

          expect(new_topic.posts.pluck(:id).sort).to eq([p2.id, p3.id].sort)
        end

        it "uses default locale for moderator post" do
          I18n.locale = 'de'

          new_topic = topic.move_posts(user, [p2.id, p4.id], title: "new testing topic name", category_id: category.id)
          post = Post.find_by(topic_id: topic.id, post_type: Post.types[:small_action])

          expected_text = I18n.with_locale(:en) do
            I18n.t("move_posts.new_topic_moderator_post",
                   count: 2,
                   topic_link: "[#{new_topic.title}](#{new_topic.relative_url})")
          end

          expect(post.raw).to eq(expected_text)
        end

        it "does not try to move small action posts" do
          small_action = Fabricate(:post, topic: topic, raw: "A small action", post_type: Post.types[:small_action])
          new_topic = topic.move_posts(user, [p2.id, p4.id, small_action.id], title: "new testing topic name", category_id: category.id)

          expect(new_topic.posts_count).to eq(2)
          expect(small_action.topic_id).to eq(topic.id)

          moderator_post = topic.posts.last
          expect(moderator_post.raw).to include("2 posts were split")
        end
      end

      context "to an existing topic" do
        let!(:destination_topic) { Fabricate(:topic, user: user) }
        let!(:destination_op) { Fabricate(:post, topic: destination_topic, user: user) }

        it "works correctly" do
          topic.expects(:add_moderator_post).once
          moved_to = topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id)
          expect(moved_to).to eq(destination_topic)

          # Check out new topic
          moved_to.reload
          expect(moved_to.posts_count).to eq(3)
          expect(moved_to.highest_post_number).to eq(3)
          expect(moved_to.user_id).to eq(p1.user_id)
          expect(moved_to.like_count).to eq(1)
          expect(moved_to.category_id).to eq(SiteSetting.uncategorized_category_id)

          # Posts should be re-ordered
          p2.reload
          expect(p2.sort_order).to eq(2)
          expect(p2.post_number).to eq(2)
          expect(p2.topic_id).to eq(moved_to.id)
          expect(p2.reply_count).to eq(1)
          expect(p2.reply_to_post_number).to eq(nil)

          p4.reload
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
          notification = p2.user.notifications.where(notification_type: Notification.types[:moved_post]).first

          expect(notification.topic_id).to eq(p2.topic_id)
          expect(notification.post_number).to eq(p2.post_number)

          # Should update last reads
          expect(TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number).to eq(p3.post_number)
        end

        it "moving all posts will close the topic" do
          topic.expects(:add_moderator_post).twice
          moved_to = topic.move_posts(user, [p1.id, p2.id, p3.id, p4.id], destination_topic_id: destination_topic.id)
          expect(moved_to).to be_present

          topic.reload
          expect(topic.closed).to eq(true)
        end

        it "does not try to move small action posts" do
          small_action = Fabricate(:post, topic: topic, raw: "A small action", post_type: Post.types[:small_action])
          moved_to = topic.move_posts(user, [p1.id, p2.id, p3.id, p4.id, small_action.id], destination_topic_id: destination_topic.id)

          moved_to.reload
          expect(moved_to.posts_count).to eq(5)
          expect(small_action.topic_id).to eq(topic.id)

          moderator_post = topic.posts.find_by(post_number: 2)
          expect(moderator_post.raw).to include("4 posts were merged")
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

          expect(old_post.reload.incoming_email).to_not be_present unless old_post.id == new_post.id
        end

        it "moves email log entries" do
          old_topic = old_post.topic
          Fabricate(:email_log, user: old_post.user, topic: old_topic, post: old_post, email_type: :mailing_list)
          Fabricate(:email_log, user: old_post.user, topic: old_topic, post: old_post, email_type: :mailing_list)
          Fabricate(:email_log, user: old_post.user, post: old_post, email_type: :mailing_list)

          expect(EmailLog.where(topic_id: old_topic.id, post_id: old_post.id).count).to eq(2)
          expect(EmailLog.where(topic_id: nil, post_id: old_post.id).count).to eq(1)

          new_topic = old_topic.move_posts(user, [old_post.id], title: "new testing topic name")
          new_post = new_topic.first_post

          expect(EmailLog.where(topic_id: old_topic.id, post_id: old_post.id).count).to eq(0)
          expect(EmailLog.where(topic_id: new_topic.id, post_id: new_post.id).count).to eq(3)
        end

        it "preserves post attributes" do
          old_post.update_columns(cook_method: Post.cook_methods[:email], via_email: true, raw_email: "raw email content")

          new_topic = old_post.topic.move_posts(user, [old_post.id], title: "new testing topic name")
          new_post = new_topic.first_post

          expect(new_post.cook_method).to eq(Post.cook_methods[:email])
          expect(new_post.via_email).to eq(true)
          expect(new_post.raw_email).to eq("raw email content")
        end
      end

      context "moving the first post" do

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
          expect(p1.reply_count).to eq(0)

          # New first post
          new_first = new_topic.posts.where(post_number: 1).first
          expect(new_first.reply_count).to eq(1)
          expect(new_first.created_at).to be_within(1.second).of(p1.created_at)

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
        end

        it "preserves post actions in the new post" do
          PostAction.act(another_user, p1, PostActionType.types[:like])

          new_topic = topic.move_posts(user, [p1.id], title: "new testing topic name")
          new_post = new_topic.posts.where(post_number: 1).first

          expect(new_topic.like_count).to eq(1)
          expect(new_post.like_count).to eq(1)
          expect(new_post.post_actions.size).to eq(1)
        end

        it "preserves the custom_fields in the new post" do
          custom_fields = { "some_field" => 'payload' }
          p1.custom_fields = custom_fields
          p1.save_custom_fields

          new_topic = topic.move_posts(user, [p1.id], title: "new testing topic name")

          expect(new_topic.first_post.custom_fields).to eq(custom_fields)
        end

        include_examples "moves email related stuff" do
          let!(:old_post) { p1 }
        end
      end

      context "moving replies" do
        include_examples "moves email related stuff" do
          let!(:old_post) { p3 }
        end
      end

      context "to an existing topic with a deleted post" do

        before do
          topic.expects(:add_moderator_post)
        end

        let!(:destination_topic) { Fabricate(:topic, user: user) }
        let!(:destination_op) { Fabricate(:post, topic: destination_topic, user: user) }
        let!(:destination_deleted_reply) { Fabricate(:post, topic: destination_topic, user: another_user) }
        let(:moved_to) { topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id) }

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

      context "to an existing closed topic" do
        let!(:destination_topic) { Fabricate(:topic, closed: true) }

        it "works correctly for admin" do
          admin = Fabricate(:admin)
          moved_to = topic.move_posts(admin, [p1.id, p2.id], destination_topic_id: destination_topic.id)
          expect(moved_to).to be_present

          moved_to.reload
          expect(moved_to.posts_count).to eq(2)
          expect(moved_to.highest_post_number).to eq(2)
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
    end
  end
end
