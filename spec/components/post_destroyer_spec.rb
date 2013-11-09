require 'spec_helper'
require 'post_destroyer'

describe PostDestroyer do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:admin) }
  let(:post) { create_post }

  describe 'destroy_old_stubs' do
    it 'destroys stubs for deleted by user posts' do
      SiteSetting.stubs(:delete_removed_posts_after).returns(24)
      Fabricate(:admin)
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

      reply1.deleted_at.should == nil
      reply2.deleted_at.should_not == nil
      reply3.deleted_at.should == nil

      # if topic is deleted we should still be able to destroy stubs

      topic.trash!
      reply1.update_column(:updated_at, 2.days.ago)
      PostDestroyer.destroy_stubs

      reply1.reload
      reply1.deleted_at.should == nil

      # flag the post, it should not nuke the stub anymore
      topic.recover!
      PostAction.act(Fabricate(:coding_horror), reply1, PostActionType.types[:spam])

      PostDestroyer.destroy_stubs

      reply1.reload
      reply1.deleted_at.should == nil

    end

    it 'uses the delete_removed_posts_after site setting' do
      Fabricate(:admin)
      topic = post.topic
      reply1 = create_post(topic: topic)
      reply2 = create_post(topic: topic)

      PostDestroyer.new(reply1.user, reply1).destroy
      PostDestroyer.new(reply2.user, reply2).destroy

      SiteSetting.stubs(:delete_removed_posts_after).returns(1)

      reply2.update_column(:updated_at, 70.minutes.ago)

      PostDestroyer.destroy_stubs

      reply1.reload
      reply2.reload

      reply1.deleted_at.should == nil
      reply2.deleted_at.should_not == nil

      SiteSetting.stubs(:delete_removed_posts_after).returns(72)

      reply1.update_column(:updated_at, 2.days.ago)

      PostDestroyer.destroy_stubs

      reply1.reload.deleted_at.should == nil

      SiteSetting.stubs(:delete_removed_posts_after).returns(47)

      PostDestroyer.destroy_stubs

      reply1.reload.deleted_at.should_not == nil
    end
  end

  describe 'basic destroying' do

    it "as the creator of the post, doesn't delete the post" do
      SiteSetting.stubs(:unique_posts_mins).returns(5)
      SiteSetting.stubs(:delete_removed_posts_after).returns(24)

      post2 = create_post # Create it here instead of with "let" so unique_posts_mins can do its thing

      @orig = post2.cooked
      PostDestroyer.new(post2.user, post2).destroy
      post2.reload

      post2.deleted_at.should be_blank
      post2.deleted_by.should be_blank
      post2.user_deleted.should be_true
      post2.raw.should == I18n.t('js.post.deleted_by_author', {count: 24})
      post2.version.should == 2

      # lets try to recover
      PostDestroyer.new(post2.user, post2).recover
      post2.reload
      post2.version.should == 3
      post2.user_deleted.should be_false
      post2.cooked.should == @orig
    end

    context "as a moderator" do
      before do
        PostDestroyer.new(moderator, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
        post.deleted_by.should == moderator
      end
    end

    context "as an admin" do
      before do
        PostDestroyer.new(admin, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
        post.deleted_by.should == admin
      end
    end

  end

  context 'deleting the second post in a topic' do

    let(:user) { Fabricate(:user) }
    let!(:post) { create_post(user: user) }
    let(:topic) { post.topic.reload }
    let(:second_user) { Fabricate(:coding_horror) }
    let!(:second_post) { create_post(topic: topic, user: second_user) }

    before do
      PostDestroyer.new(moderator, second_post).destroy
    end

    it 'resets the last_poster_id back to the OP' do
      topic.last_post_user_id.should == user.id
    end

    it 'resets the last_posted_at back to the OP' do
      topic.last_posted_at.to_i.should == post.created_at.to_i
    end

    context 'topic_user' do

      let(:topic_user) { second_user.topic_users.where(topic_id: topic.id).first }

      it 'clears the posted flag for the second user' do
        topic_user.posted?.should be_false
      end

      it "sets the second user's last_read_post_number back to 1" do
        topic_user.last_read_post_number.should == 1
      end

      it "sets the second user's last_read_post_number back to 1" do
        topic_user.seen_post_count.should == 1
      end

    end

  end

  context "deleting a post belonging to a deleted topic" do
    let!(:topic) { post.topic }

    before do
      topic.trash!(admin)
      post.reload
    end

    context "as a moderator" do
      before do
        PostDestroyer.new(moderator, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
        post.deleted_by.should == moderator
      end
    end

    context "as an admin" do
      before do
        PostDestroyer.new(admin, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
        post.deleted_by.should == admin
      end
    end
  end

  describe 'after delete' do

    let!(:coding_horror) { Fabricate(:coding_horror) }
    let!(:post) { Fabricate(:post, raw: "Hello @CodingHorror") }

    it "should feature the users again (in case they've changed)" do
      Jobs.expects(:enqueue).with(:feature_topic_users, has_entries(topic_id: post.topic_id, except_post_id: post.id))
      PostDestroyer.new(moderator, post).destroy
    end

    describe 'with a reply' do

      let!(:reply) { Fabricate(:basic_reply, user: coding_horror, topic: post.topic) }
      let!(:post_reply) { PostReply.create(post_id: post.id, reply_id: reply.id) }

      it 'changes the post count of the topic' do
        post.reload
        lambda {
          PostDestroyer.new(moderator, reply).destroy
          post.topic.reload
        }.should change(post.topic, :posts_count).by(-1)
      end

      it 'lowers the reply_count when the reply is deleted' do
        lambda {
          PostDestroyer.new(moderator, reply).destroy
        }.should change(post.post_replies, :count).by(-1)
      end

      it 'should increase the post_number when there are deletion gaps' do
        PostDestroyer.new(moderator, reply).destroy
        p = Fabricate(:post, user: post.user, topic: post.topic)
        p.post_number.should == 3
      end

    end

  end

  context '@mentions' do
    let!(:evil_trout) { Fabricate(:evil_trout) }
    let!(:mention_post) { Fabricate(:post, raw: 'Hello @eviltrout')}

    it 'removes notifications when deleted' do
      lambda {
        PostDestroyer.new(Fabricate(:moderator), mention_post).destroy
      }.should change(evil_trout.notifications, :count).by(-1)
    end
  end

  describe "post actions" do
    let(:codinghorror) { Fabricate(:coding_horror) }
    let(:bookmark) { PostAction.new(user_id: post.user_id, post_action_type_id: PostActionType.types[:bookmark] , post_id: post.id) }
    let(:second_post) { Fabricate(:post, topic_id: post.topic_id) }

    it "should reset counts when a post is deleted" do
      PostAction.act(codinghorror, second_post, PostActionType.types[:off_topic])
      expect { PostDestroyer.new(moderator, second_post).destroy }.to change(PostAction, :flagged_posts_count).by(-1)
    end

    it "should delete the post actions" do
      flag = PostAction.act(codinghorror, second_post, PostActionType.types[:off_topic])
      PostDestroyer.new(moderator, second_post).destroy
      expect(PostAction.where(id: flag.id).first).to be_nil
      expect(PostAction.where(id: bookmark.id).first).to be_nil
    end

    it 'should update flag counts on the post' do
      PostAction.act(codinghorror, second_post, PostActionType.types[:off_topic])
      PostDestroyer.new(moderator, second_post.reload).destroy
      second_post.reload
      expect(second_post.off_topic_count).to eq(0)
      expect(second_post.bookmark_count).to eq(0)
    end
  end

  describe 'topic links' do
    let!(:first_post)  { Fabricate(:post) }
    let!(:topic)       { first_post.topic }
    let!(:second_post) { Fabricate(:post_with_external_links, topic: topic) }

    before { TopicLink.extract_from(second_post) }

    it 'should destroy the topic links when moderator destroys the post' do
      PostDestroyer.new(moderator, second_post.reload).destroy
      expect(topic.topic_links.count).to eq(0)
    end

    it 'should destroy the topic links when the user destroys the post' do
      PostDestroyer.new(second_post.user, second_post.reload).destroy
      expect(topic.topic_links.count).to eq(0)
    end
  end

end

