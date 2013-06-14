require 'spec_helper'
require 'post_destroyer'

describe PostDestroyer do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  let(:moderator) { Fabricate(:moderator) }
  let(:post) { Fabricate(:post) }

  describe 'basic destroying' do

    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }

    context "as the creator of the post" do
      before do
        PostDestroyer.new(post.user, post).destroy
        post.reload
      end

      it "doesn't delete the post" do
        post.deleted_at.should be_blank
        post.raw.should == I18n.t('js.post.deleted_by_author')
        post.version.should == 2
      end
    end

    context "as a moderator" do
      before do
        PostDestroyer.new(moderator, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
      end
    end

    context "as an admin" do
      before do
        PostDestroyer.new(admin, post).destroy
      end

      it "deletes the post" do
        post.deleted_at.should be_present
      end
    end

  end

  context 'deleting the second post in a topic' do

    let(:user) { Fabricate(:user) }
    let!(:post) { Fabricate(:post, user: user) }
    let(:topic) { post.topic }
    let(:second_user) { Fabricate(:coding_horror) }
    let!(:second_post) { Fabricate(:post, topic: topic, user: second_user) }

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

