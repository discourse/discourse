require 'spec_helper'

describe PostAction do

  it { should belong_to :user }
  it { should belong_to :post }
  it { should belong_to :post_action_type }
  it { should rate_limit }

  let(:codinghorror) { Fabricate(:coding_horror) }
  let(:post) { Fabricate(:post) }
  let(:bookmark) { PostAction.new(user_id: post.user_id, post_action_type_id: PostActionType.types[:bookmark] , post_id: post.id) }

  describe "flag counts" do
    before do
      PostAction.update_flagged_posts_count
    end
    it "starts of with 0 flag counts" do
      PostAction.flagged_posts_count.should == 0
    end

    it "increments the numbers correctly" do
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      PostAction.flagged_posts_count.should == 1

      PostAction.clear_flags!(post, -1)
      PostAction.flagged_posts_count.should == 0
    end

    it "should reset counts when a topic is deleted" do
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      post.topic.destroy
      PostAction.flagged_posts_count.should == 0
    end

    it "should reset counts when a post is deleted" do
      post2 = Fabricate(:post, topic_id: post.topic_id)
      PostAction.act(codinghorror, post2, PostActionType.types[:off_topic])
      post2.destroy
      PostAction.flagged_posts_count.should == 0
    end

  end

  it "increases the post's bookmark count when saved" do
    lambda { bookmark.save; post.reload }.should change(post, :bookmark_count).by(1)
  end

  it "increases the forum topic's bookmark count when saved" do
    lambda { bookmark.save; post.topic.reload }.should change(post.topic, :bookmark_count).by(1)
  end


  describe 'when a user likes something' do
    it 'should increase the post counts when a user likes' do
      lambda {
        PostAction.act(codinghorror, post, PostActionType.types[:like])
        post.reload
      }.should change(post, :like_count).by(1)
    end

    it 'should increase the forum topic like count when a user likes' do
      lambda {
        PostAction.act(codinghorror, post, PostActionType.types[:like])
        post.topic.reload
      }.should change(post.topic, :like_count).by(1)
    end

  end


  describe 'when a user votes for something' do
    it 'should increase the vote counts when a user likes' do
      lambda {
        PostAction.act(codinghorror, post, PostActionType.types[:vote])
        post.reload
      }.should change(post, :vote_count).by(1)
    end

    it 'should increase the forum topic vote count when a user votes' do
      lambda {
        PostAction.act(codinghorror, post, PostActionType.types[:vote])
        post.topic.reload
      }.should change(post.topic, :vote_count).by(1)
    end
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
      lambda {
        post.reload
      }.should change(post, :bookmark_count).by(-1)
    end

    it 'reduces the bookmark count of the forum topic' do
      lambda {
        @topic.reload
      }.should change(post.topic, :bookmark_count).by(-1)
    end
  end

  describe 'flagging' do

    it 'does not allow you to flag stuff with 2 reasons' do
      post = Fabricate(:post)
      u1 = Fabricate(:evil_trout)
      PostAction.act(u1, post, PostActionType.types[:spam])
      lambda { PostAction.act(u1, post, PostActionType.types[:off_topic]) }.should raise_error(PostAction::AlreadyFlagged)
    end

    it 'should update counts when you clear flags' do
      post = Fabricate(:post)
      u1 = Fabricate(:evil_trout)
      PostAction.act(u1, post, PostActionType.types[:spam])

      post.reload
      post.spam_count.should == 1

      PostAction.clear_flags!(post, -1)
      post.reload

      post.spam_count.should == 0
    end

    it 'should follow the rules for automatic hiding workflow' do

      post = Fabricate(:post)
      u1 = Fabricate(:evil_trout)
      u2 = Fabricate(:walter_white)

      # we need an admin for the messages
      admin = Fabricate(:admin)

      SiteSetting.flags_required_to_hide_post = 2

      PostAction.act(u1, post, PostActionType.types[:spam])
      PostAction.act(u2, post, PostActionType.types[:spam])

      post.reload

      post.hidden.should.should be_true
      post.hidden_reason_id.should == Post::HiddenReason::FLAG_THRESHOLD_REACHED
      post.topic.visible.should be_false

      post.revise(post.user, post.raw + " ha I edited it ")
      post.reload

      post.hidden.should be_false
      post.hidden_reason_id.should be_nil
      post.topic.visible.should be_true

      PostAction.act(u1, post, PostActionType.types[:spam])
      PostAction.act(u2, post, PostActionType.types[:off_topic])

      post.reload

      post.hidden.should be_true
      post.hidden_reason_id.should == Post::HiddenReason::FLAG_THRESHOLD_REACHED_AGAIN

      post.revise(post.user, post.raw + " ha I edited it again ")

      post.reload

      post.hidden.should be_true
      post.hidden_reason_id.should == Post::HiddenReason::FLAG_THRESHOLD_REACHED_AGAIN
    end
  end

end
