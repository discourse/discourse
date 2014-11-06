require 'spec_helper'
require_dependency 'post_destroyer'

describe PostAction do
  it { should belong_to :user }
  it { should belong_to :post }
  it { should belong_to :post_action_type }
  it { should rate_limit }

  let(:moderator) { Fabricate(:moderator) }
  let(:codinghorror) { Fabricate(:coding_horror) }
  let(:eviltrout) { Fabricate(:evil_trout) }
  let(:admin) { Fabricate(:admin) }
  let(:post) { Fabricate(:post) }
  let(:second_post) { Fabricate(:post, topic_id: post.topic_id) }
  let(:bookmark) { PostAction.new(user_id: post.user_id, post_action_type_id: PostActionType.types[:bookmark] , post_id: post.id) }

  describe "messaging" do

    it "notify moderators integration test" do
      post = create_post
      mod = moderator
      Group.refresh_automatic_groups!

      action = PostAction.act(codinghorror, post, PostActionType.types[:notify_moderators], message: "this is my special long message");

      posts = Post.joins(:topic)
                  .select('posts.id, topics.subtype, posts.topic_id')
                  .where('topics.archetype' => Archetype.private_message)
                  .to_a

      posts.count.should == 1
      action.related_post_id.should == posts[0].id.to_i
      posts[0].subtype.should == TopicSubtype.notify_moderators

      topic = posts[0].topic

      # Moderators should be invited to the private topic, otherwise they're not permitted to see it
      topic_user_ids = topic.topic_users(true).map {|x| x.user_id}
      topic_user_ids.should include(codinghorror.id)
      topic_user_ids.should include(mod.id)

      # Notification level should be "Watching" for everyone
      topic.topic_users(true).map(&:notification_level).uniq.should == [TopicUser.notification_levels[:watching]]

      # reply to PM should not clear flag
      PostCreator.new(mod, topic_id: posts[0].topic_id, raw: "This is my test reply to the user, it should clear flags").create
      action.reload
      action.deleted_at.should == nil

      # Acting on the flag should post an automated status message
      topic.posts.count.should == 2
      PostAction.agree_flags!(post, admin)
      topic.reload
      topic.posts.count.should == 3
      topic.posts.last.post_type.should == Post.types[:moderator_action]

      # Clearing the flags should not post another automated status message
      PostAction.act(mod, post, PostActionType.types[:notify_moderators], message: "another special message")
      PostAction.clear_flags!(post, admin)
      topic.reload
      topic.posts.count.should == 3
    end

    describe 'notify_moderators' do
      before do
        PostAction.stubs(:create)
      end

      it "creates a pm if selected" do
        post = build(:post, id: 1000)
        PostCreator.any_instance.expects(:create).returns(post)
        PostAction.act(build(:user), build(:post), PostActionType.types[:notify_moderators], message: "this is my special message");
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
        PostAction.act(build(:user), post, PostActionType.types[:notify_user], message: "this is my special message");
      end
    end
  end

  describe "flag counts" do
    before do
      PostAction.update_flagged_posts_count
    end

    it "increments the numbers correctly" do
      PostAction.flagged_posts_count.should == 0

      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      PostAction.flagged_posts_count.should == 1

      PostAction.clear_flags!(post, Discourse.system_user)
      PostAction.flagged_posts_count.should == 0
    end

    it "should reset counts when a topic is deleted" do
      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      post.topic.trash!
      PostAction.flagged_posts_count.should == 0
    end

    it "should ignore validated flags" do
      post = create_post

      PostAction.act(codinghorror, post, PostActionType.types[:off_topic])
      post.hidden.should == false
      post.hidden_at.should be_blank
      PostAction.defer_flags!(post, admin)
      PostAction.flagged_posts_count.should == 0

      post.reload
      post.hidden.should == false
      post.hidden_at.should be_blank

      PostAction.hide_post!(post, PostActionType.types[:off_topic])

      post.reload
      post.hidden.should == true
      post.hidden_at.should be_present
    end

  end

  describe "update_counters" do

    it "properly updates topic counters" do
      PostAction.act(moderator, post, PostActionType.types[:like])
      PostAction.act(codinghorror, second_post, PostActionType.types[:like])

      post.topic.reload
      post.topic.like_count.should == 2
    end

  end

  describe "when a user bookmarks something" do
    it "increases the post's bookmark count when saved" do
      lambda { bookmark.save; post.reload }.should change(post, :bookmark_count).by(1)
    end

    it "increases the forum topic's bookmark count when saved" do
      lambda { bookmark.save; post.topic.reload }.should change(post.topic, :bookmark_count).by(1)
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
        lambda { post.reload }.should change(post, :bookmark_count).by(-1)
      end

      it 'reduces the bookmark count of the forum topic' do
        lambda { @topic.reload }.should change(post.topic, :bookmark_count).by(-1)
      end
    end
  end

  describe 'when a user likes something' do
    it 'should increase the `like_count` and `like_score` when a user likes something' do
      PostAction.act(codinghorror, post, PostActionType.types[:like])
      post.reload
      post.like_count.should == 1
      post.like_score.should == 1
      post.topic.reload
      post.topic.like_count.should == 1

      # When a staff member likes it
      PostAction.act(moderator, post, PostActionType.types[:like])
      post.reload
      post.like_count.should == 2
      post.like_score.should == 4

      # Removing likes
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])
      post.reload
      post.like_count.should == 1
      post.like_score.should == 3

      PostAction.remove_act(moderator, post, PostActionType.types[:like])
      post.reload
      post.like_count.should == 0
      post.like_score.should == 0
    end
  end

  describe "undo/redo repeatedly" do
    it "doesn't create a second action for the same user/type" do
      PostAction.act(codinghorror, post, PostActionType.types[:like])
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])
      PostAction.act(codinghorror, post, PostActionType.types[:like])
      PostAction.where(post: post).with_deleted.count.should == 1
      PostAction.remove_act(codinghorror, post, PostActionType.types[:like])

      # Check that we don't lose consistency into negatives
      post.reload.like_count.should == 0
    end
  end

  describe 'when a user votes for something' do
    it 'should increase the vote counts when a user votes' do
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

  describe 'flagging' do

    context "flag_counts_for" do
      it "returns the correct flag counts" do
        post = create_post

        SiteSetting.stubs(:flags_required_to_hide_post).returns(7)

        # A post with no flags has 0 for flag counts
        PostAction.flag_counts_for(post.id).should == [0, 0]

        flag = PostAction.act(eviltrout, post, PostActionType.types[:spam])
        PostAction.flag_counts_for(post.id).should == [0, 1]

        # If staff takes action, it is ranked higher
        PostAction.act(admin, post, PostActionType.types[:spam], take_action: true)
        PostAction.flag_counts_for(post.id).should == [0, 8]

        # If a flag is dismissed
        PostAction.clear_flags!(post, admin)
        PostAction.flag_counts_for(post.id).should == [8, 0]
      end
    end

    it 'does not allow you to flag stuff with the same reason more than once' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      lambda { PostAction.act(eviltrout, post, PostActionType.types[:off_topic]) }.should raise_error(PostAction::AlreadyActed)
    end

    it 'allows you to flag stuff with another reason' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.remove_act(eviltrout, post, PostActionType.types[:spam])
      lambda { PostAction.act(eviltrout, post, PostActionType.types[:off_topic]) }.should_not raise_error()
    end

    it 'should update counts when you clear flags' do
      post = Fabricate(:post)
      PostAction.act(eviltrout, post, PostActionType.types[:spam])

      post.reload
      post.spam_count.should == 1

      PostAction.clear_flags!(post, Discourse.system_user)

      post.reload
      post.spam_count.should == 0
    end

    it 'should follow the rules for automatic hiding workflow' do
      post = create_post
      walterwhite = Fabricate(:walter_white)

      SiteSetting.stubs(:flags_required_to_hide_post).returns(2)
      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(walterwhite, post, PostActionType.types[:spam])

      post.reload

      post.hidden.should == true
      post.hidden_at.should be_present
      post.hidden_reason_id.should == Post.hidden_reasons[:flag_threshold_reached]
      post.topic.visible.should == false

      post.revise(post.user, { raw: post.raw + " ha I edited it " })

      post.reload

      post.hidden.should == false
      post.hidden_reason_id.should == nil
      post.hidden_at.should be_blank
      post.topic.visible.should == true

      PostAction.act(eviltrout, post, PostActionType.types[:spam])
      PostAction.act(walterwhite, post, PostActionType.types[:off_topic])

      post.reload

      post.hidden.should == true
      post.hidden_at.should be_present
      post.hidden_reason_id.should == Post.hidden_reasons[:flag_threshold_reached_again]
      post.topic.visible.should == false

      post.revise(post.user, { raw: post.raw + " ha I edited it again " })

      post.reload

      post.hidden.should == true
      post.hidden_at.should be_present
      post.hidden_reason_id.should == Post.hidden_reasons[:flag_threshold_reached_again]
      post.topic.visible.should == false
    end

    it "hide tl0 posts that are flagged as spam by a tl3 user" do
      newuser = Fabricate(:newuser)
      post = create_post(user: newuser)

      Discourse.stubs(:site_contact_user).returns(admin)

      PostAction.act(Fabricate(:leader), post, PostActionType.types[:spam])

      post.reload

      post.hidden.should == true
      post.hidden_at.should be_present
      post.hidden_reason_id.should == Post.hidden_reasons[:flagged_by_tl3_user]
    end

    it "can flag the topic instead of a post" do
      post1 = create_post
      post2 = create_post(topic: post1.topic)
      post_action = PostAction.act(Fabricate(:user), post1, PostActionType.types[:spam], { flag_topic: true })
      post_action.targets_topic.should == true
    end

    it "will flag the first post if you flag a topic but there is only one post in the topic" do
      post = create_post
      post_action = PostAction.act(Fabricate(:user), post, PostActionType.types[:spam], { flag_topic: true })
      post_action.targets_topic.should == false
      post_action.post_id.should == post.id
    end

    it "will unhide the post when a moderator undos the flag on which s/he took action" do
      Discourse.stubs(:site_contact_user).returns(admin)

      post = create_post
      PostAction.act(moderator, post, PostActionType.types[:spam], { take_action: true })

      post.reload
      post.hidden.should == true

      PostAction.remove_act(moderator, post, PostActionType.types[:spam])

      post.reload
      post.hidden.should == false
    end

  end

  it "prevents user to act twice at the same time" do
    post = Fabricate(:post)

    # flags are already being tested
    all_types_except_flags = PostActionType.types.except(PostActionType.flag_types)
    all_types_except_flags.values.each do |action|
      lambda do
        PostAction.act(eviltrout, post, action)
        PostAction.act(eviltrout, post, action)
      end.should raise_error(PostAction::AlreadyActed)
    end
  end

end
