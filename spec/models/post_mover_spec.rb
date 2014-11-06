require 'spec_helper'

describe PostMover do

  context 'move_posts' do
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:evil_trout) }
    let(:category) { Fabricate(:category, user: user) }
    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:p1) { Fabricate(:post, topic: topic, user: user) }
    let!(:p2) { Fabricate(:post, topic: topic, user: another_user, raw: "Has a link to [evil trout](http://eviltrout.com) which is a cool site.", reply_to_post_number: p1.post_number)}
    let!(:p3) { Fabricate(:post, topic: topic, reply_to_post_number: p1.post_number, user: user)}
    let!(:p4) { Fabricate(:post, topic: topic, reply_to_post_number: p2.post_number, user: user)}

    before do
      # add a like to a post, enable observers so we get user actions
      ActiveRecord::Base.observers.enable :all
      @like = PostAction.act(another_user, p4, PostActionType.types[:like])
    end

    context 'success' do

      it "enqueues a job to notify users" do
        topic.stubs(:add_moderator_post)
        Jobs.expects(:enqueue).with(:notify_moved_posts, post_ids: [p2.id, p4.id], moved_by_id: user.id)
        topic.move_posts(user, [p2.id, p4.id], title: "new testing topic name")
      end

      it "adds a moderator post at the location of the first moved post" do
        topic.expects(:add_moderator_post).with(user, instance_of(String), has_entries(post_number: 2))
        topic.move_posts(user, [p2.id, p4.id], title: "new testing topic name")
      end

    end

    context "errors" do

      it "raises an error when one of the posts doesn't exist" do
        lambda { topic.move_posts(user, [1003], title: "new testing topic name") }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error and does not create a topic if no posts were moved" do
        Topic.count.tap do |original_topic_count|
          lambda {
            topic.move_posts(user, [], title: "new testing topic name")
          }.should raise_error(Discourse::InvalidParameters)

          expect(Topic.count).to eq original_topic_count
        end
      end
    end

    context "successfully moved" do
      before do
        topic.expects(:add_moderator_post)
        TopicUser.update_last_read(user, topic.id, p4.post_number, 0)
        TopicLink.extract_from(p2)
      end

      context "to a new topic" do
        let!(:new_topic) { topic.move_posts(user, [p2.id, p4.id], title: "new testing topic name", category_id: category.id) }

        it "works correctly" do
          TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number.should == p3.post_number

          new_topic.should be_present
          new_topic.featured_user1_id.should == another_user.id
          new_topic.like_count.should == 1

          new_topic.category.should == category
          topic.featured_user1_id.should be_blank
          new_topic.posts.by_post_number.should =~ [p2, p4]

          new_topic.reload
          new_topic.posts_count.should == 2
          new_topic.highest_post_number.should == 2
          new_topic.last_post_user_id.should == new_topic.posts.last.user_id
          expect(new_topic.last_posted_at).to be_present

          p2.reload
          p2.sort_order.should == 1
          p2.post_number.should == 1
          p2.topic_links.first.topic_id.should == new_topic.id

          p4.reload
          p4.post_number.should == 2
          p4.sort_order.should == 2

          topic.reload
          topic.featured_user1_id.should be_blank
          topic.like_count.should == 0
          topic.posts_count.should == 2
          topic.posts.by_post_number.should =~ [p1, p3]
          topic.highest_post_number.should == p3.post_number

          # both the like and was_liked user actions should be correct
          action = UserAction.find_by(user_id: another_user.id)
          action.target_topic_id.should == new_topic.id
        end
      end

      context "to an existing topic" do

        let!(:destination_topic) { Fabricate(:topic, user: user ) }
        let!(:destination_op) { Fabricate(:post, topic: destination_topic, user: user) }
        let!(:moved_to) { topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id)}

        it "works correctly" do
          moved_to.should == destination_topic

          # Check out new topic
          moved_to.reload
          moved_to.posts_count.should == 3
          moved_to.highest_post_number.should == 3
          moved_to.featured_user1_id.should == another_user.id
          moved_to.like_count.should == 1
          moved_to.category_id.should == SiteSetting.uncategorized_category_id

          # Posts should be re-ordered
          p2.reload
          p2.sort_order.should == 2
          p2.post_number.should == 2
          p2.topic_id.should == moved_to.id
          p2.reply_count.should == 1
          p2.reply_to_post_number.should == nil

          p4.reload
          p4.post_number.should == 3
          p4.sort_order.should == 3
          p4.topic_id.should == moved_to.id
          p4.reply_count.should == 0
          p4.reply_to_post_number.should == 2

          # Check out the original topic
          topic.reload
          topic.posts_count.should == 2
          topic.highest_post_number.should == 3
          topic.featured_user1_id.should be_blank
          topic.like_count.should == 0
          topic.posts_count.should == 2
          topic.posts.by_post_number.should =~ [p1, p3]
          topic.highest_post_number.should == p3.post_number

          # Should update last reads
          TopicUser.find_by(user_id: user.id, topic_id: topic.id).last_read_post_number.should == p3.post_number
        end
      end

      context "moving the first post" do

        let!(:new_topic) { topic.move_posts(user, [p1.id, p2.id], title: "new testing topic name") }

        it "copies the OP, doesn't delete it" do
          new_topic.should be_present
          new_topic.posts.reload
          new_topic.posts.by_post_number.first.raw.should == p1.raw

          new_topic.reload
          new_topic.posts_count.should == 2
          new_topic.highest_post_number.should == 2

          # First post didn't move
          p1.reload
          p1.sort_order.should == 1
          p1.post_number.should == 1
          p1.topic_id == topic.id
          p1.reply_count.should == 0

          # New first post
          new_first = new_topic.posts.where(post_number: 1).first
          new_first.reply_count.should == 1

          # Second post is in a new topic
          p2.reload
          p2.post_number.should == 2
          p2.sort_order.should == 2
          p2.topic_id == new_topic.id
          p2.reply_to_post_number.should == 1
          p2.reply_count.should == 0

          topic.reload
          topic.posts.by_post_number.should =~ [p1, p3, p4]
          topic.highest_post_number.should == p4.post_number
        end

      end

      context "to an existing topic with a deleted post" do

        let!(:destination_topic) { Fabricate(:topic, user: user ) }
        let!(:destination_op) { Fabricate(:post, topic: destination_topic, user: user) }
        let!(:destination_deleted_reply) { Fabricate(:post, topic: destination_topic, user: another_user) }
        let(:moved_to) { topic.move_posts(user, [p2.id, p4.id], destination_topic_id: destination_topic.id)}

        it "works correctly" do
          destination_deleted_reply.trash!

          moved_to.should == destination_topic

          # Check out new topic
          moved_to.reload
          moved_to.posts_count.should == 3
          moved_to.highest_post_number.should == 4

          # Posts should be re-ordered
          p2.reload
          p2.sort_order.should == 3
          p2.post_number.should == 3
          p2.topic_id.should == moved_to.id
          p2.reply_count.should == 1
          p2.reply_to_post_number.should == nil

          p4.reload
          p4.post_number.should == 4
          p4.sort_order.should == 4
          p4.topic_id.should == moved_to.id
          p4.reply_to_post_number.should == p2.post_number
        end
      end


    end
  end
end
