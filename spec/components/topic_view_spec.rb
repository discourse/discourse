require 'spec_helper'
require 'topic_view'

describe TopicView do

  let(:topic) { create_topic }
  let(:coding_horror) { Fabricate(:coding_horror) }
  let(:first_poster) { topic.user }

  let(:topic_view) { TopicView.new(topic.id, coding_horror) }

  it "raises a not found error if the topic doesn't exist" do
    lambda { TopicView.new(1231232, coding_horror) }.should raise_error(Discourse::NotFound)
  end

  it "raises an error if the user can't see the topic" do
    Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
    lambda { topic_view }.should raise_error(Discourse::InvalidAccess)
  end

  it "handles deleted topics" do
    admin = Fabricate(:admin)
    topic.trash!(admin)
    lambda { TopicView.new(topic.id, Fabricate(:user)) }.should raise_error(Discourse::NotFound)
    lambda { TopicView.new(topic.id, admin) }.should_not raise_error
  end


  context "with a few sample posts" do
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1 )}
    let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror, percent_rank: 0.5 )}
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0 )}

    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin)
    }
    it "it can find the best responses" do

      best2 = TopicView.new(topic.id, coding_horror, best: 2)
      best2.posts.count.should == 2
      best2.posts[0].id.should == p2.id
      best2.posts[1].id.should == p3.id

      topic.update_status('closed', true, Fabricate(:admin))
      topic.posts.count.should == 4

      # should not get the status post
      best = TopicView.new(topic.id, nil, best: 99)
      best.posts.count.should == 2
      best.filtered_post_ids.size.should == 3
      best.current_post_ids.should =~ [p2.id, p3.id]

      # should get no results for trust level too low
      best = TopicView.new(topic.id, nil, best: 99, min_trust_level: coding_horror.trust_level + 1)
      best.posts.count.should == 0


      # should filter out the posts with a score that is too low
      best = TopicView.new(topic.id, nil, best: 99, min_score: 99)
      best.posts.count.should == 0

      # should filter out everything if min replies not met
      best = TopicView.new(topic.id, nil, best: 99, min_replies: 99)
      best.posts.count.should == 0

      # should punch through posts if the score is high enough
      p2.update_column(:score, 100)

      best = TopicView.new(topic.id, nil, best: 99, bypass_trust_level_score: 100, min_trust_level: coding_horror.trust_level + 1)
      best.posts.count.should == 1

      # 0 means ignore
      best = TopicView.new(topic.id, nil, best: 99, bypass_trust_level_score: 0, min_trust_level: coding_horror.trust_level + 1)
      best.posts.count.should == 0

      # If we restrict to posts a moderator liked, return none
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      best.posts.count.should == 0

      # It doesn't count likes from admins
      PostAction.act(admin, p3, PostActionType.types[:like])
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      best.posts.count.should == 0

      # It should find the post liked by the moderator
      PostAction.act(moderator, p2, PostActionType.types[:like])
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      best.posts.count.should == 1

    end

    it "raises NotLoggedIn if the user isn't logged in and is trying to view a private message" do
      Topic.any_instance.expects(:private_message?).returns(true)
      lambda { TopicView.new(topic.id, nil) }.should raise_error(Discourse::NotLoggedIn)
    end

    it "provides an absolute url" do
      topic_view.absolute_url.should be_present
    end

    it "provides a summary of the first post" do
      topic_view.summary.should be_present
    end

    describe "#get_canonical_path" do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic) }
      let(:path) { "/1234" }

      before do
        topic.stubs(:relative_url).returns(path)
        TopicView.any_instance.stubs(:find_topic).with(1234).returns(topic)
      end

      it "generates canonical path correctly" do
        TopicView.new(1234, user).canonical_path.should eql(path)
        TopicView.new(1234, user, page: 5).canonical_path.should eql("/1234?page=5")
      end

      it "generates a canonical correctly for paged results" do
        SiteSetting.stubs(:posts_chunksize).returns(5)
        TopicView.new(1234, user, post_number: 50).canonical_path.should eql("/1234?page=10")
      end
    end

    describe "#next_page" do
      let(:p2) { stub(post_number: 2) }
      let(:topic) do
        topic = create_topic
        topic.stubs(:highest_post_number).returns(5)
        topic
      end
      let(:user) { Fabricate(:user) }

      before do
        TopicView.any_instance.expects(:find_topic).with(1234).returns(topic)
        TopicView.any_instance.stubs(:filter_posts)
        TopicView.any_instance.stubs(:last_post).returns(p2)
        SiteSetting.stubs(:posts_chunksize).returns(2)
      end

      it "should return the next page" do
        TopicView.new(1234, user).next_page.should eql(2)
      end
    end

    context '.post_counts_by_user' do
      it 'returns the two posters with their counts' do
        topic_view.post_counts_by_user.to_a.should =~ [[first_poster.id, 2], [coding_horror.id, 1]]
      end
    end

    context '.participants' do
      it 'returns the two participants hashed by id' do
        topic_view.participants.to_a.should =~ [[first_poster.id, first_poster], [coding_horror.id, coding_horror]]
      end
    end

    context '.all_post_actions' do
      it 'is blank at first' do
        topic_view.all_post_actions.should be_blank
      end

      it 'returns the like' do
        PostAction.act(coding_horror, p1, PostActionType.types[:like])
        topic_view.all_post_actions[p1.id][PostActionType.types[:like]].should be_present
      end
    end

    context '.all_active_flags' do
      it 'is blank at first' do
        topic_view.all_active_flags.should be_blank
      end

      it 'returns the active flags' do
        PostAction.act(moderator, p1, PostActionType.types[:off_topic])
        PostAction.act(coding_horror, p1, PostActionType.types[:off_topic])

        topic_view.all_active_flags[p1.id][PostActionType.types[:off_topic]].count.should == 2
      end

      it 'returns only the active flags' do
        PostAction.act(moderator, p1, PostActionType.types[:off_topic])
        PostAction.act(coding_horror, p1, PostActionType.types[:off_topic])

        PostAction.defer_flags!(p1, moderator)

        topic_view.all_active_flags[p1.id].should == nil
      end
    end


    context '.read?' do
      it 'tracks correctly' do
        # anon is assumed to have read everything
        TopicView.new(topic.id).read?(1).should == true

        # random user has nothing
        topic_view.read?(1).should == false

        # a real user that just read it should have it marked
        PostTiming.process_timings(coding_horror, topic.id, 1, [[1,1000]])
        TopicView.new(topic.id, coding_horror).read?(1).should == true
        TopicView.new(topic.id, coding_horror).topic_user.should be_present
      end
    end

    context '.topic_user' do
      it 'returns nil when there is no user' do
        TopicView.new(topic.id, nil).topic_user.should be_blank
      end
    end

    context '#recent_posts' do
      before do
        24.times do |t| # our let()s have already created 3
          Fabricate(:post, topic: topic, user: first_poster, created_at: t.seconds.from_now)
        end
      end

      it 'returns at most 25 recent posts ordered newest first' do
        recent_posts = topic_view.recent_posts

        # count
        recent_posts.count.should == 25

        # ordering
        recent_posts.include?(p1).should == false
        recent_posts.include?(p3).should == true
        recent_posts.first.created_at.should > recent_posts.last.created_at
      end
    end

  end

  context '.posts' do

    # Create the posts in a different order than the sort_order
    let!(:p5) { Fabricate(:post, topic: topic, user: coding_horror)}
    let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror)}
    let!(:p6) { Fabricate(:post, topic: topic, user: Fabricate(:user), deleted_at: Time.now)}
    let!(:p4) { Fabricate(:post, topic: topic, user: coding_horror, deleted_at: Time.now)}
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster)}
    let!(:p7) { Fabricate(:post, topic: topic, user: coding_horror, deleted_at: Time.now)}
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster)}

    before do
      SiteSetting.posts_chunksize = 3

      # Update them to the sort order we're checking for
      [p1, p2, p3, p4, p5, p6, p7].each_with_index do |p, idx|
        p.sort_order = idx + 1
        p.save
      end
      p6.user_id = nil # user got nuked
      p6.save!
    end

    describe "contains_gaps?" do
      it "works" do
        # does not contain contains_gaps with default filtering
        topic_view.contains_gaps?.should == false
        # contains contains_gaps when filtered by username" do
        TopicView.new(topic.id, coding_horror, username_filters: ['eviltrout']).contains_gaps?.should == true
        # contains contains_gaps when filtered by summary
        TopicView.new(topic.id, coding_horror, filter: 'summary').contains_gaps?.should == true
        # contains contains_gaps when filtered by best
        TopicView.new(topic.id, coding_horror, best: 5).contains_gaps?.should == true
      end
    end

    it "#restricts to correct topic" do
      t2 = Fabricate(:topic)

      category = Fabricate(:category, name: "my test")
      category.set_permissions(Group[:admins] => :full)
      category.save

      topic.category_id = category.id
      topic.save!

      expect{
        TopicView.new(topic.id, coding_horror).posts.count
      }.to raise_error(Discourse::InvalidAccess)

      TopicView.new(t2.id, coding_horror, post_ids: [p1.id,p2.id]).posts.count.should == 0

    end


    describe '#filter_posts_paged' do
      before { SiteSetting.stubs(:posts_chunksize).returns(2) }

      it 'returns correct posts for all pages' do
        topic_view.filter_posts_paged(1).should == [p1, p2]
        topic_view.filter_posts_paged(2).should == [p3, p5]
        topic_view.filter_posts_paged(3).should == []
        topic_view.filter_posts_paged(100).should == []
      end
    end

    describe "filter_posts_near" do

      def topic_view_near(post, show_deleted=false)
        TopicView.new(topic.id, coding_horror, post_number: post.post_number, show_deleted: show_deleted)
      end

      it "snaps to the lower boundary" do
        near_view = topic_view_near(p1)
        near_view.desired_post.should == p1
        near_view.posts.should == [p1, p2, p3]
        near_view.contains_gaps?.should == false
      end

      it "snaps to the upper boundary" do
        near_view = topic_view_near(p5)
        near_view.desired_post.should == p5
        near_view.posts.should == [p2, p3, p5]
        near_view.contains_gaps?.should == false
      end

      it "returns the posts in the middle" do
        near_view = topic_view_near(p2)
        near_view.desired_post.should == p2
        near_view.posts.should == [p1, p2, p3]
        near_view.contains_gaps?.should == false
      end

      it "gaps deleted posts to an admin" do
        coding_horror.admin = true
        near_view = topic_view_near(p3)
        near_view.desired_post.should == p3
        near_view.posts.should == [p2, p3, p5]
        near_view.gaps.before.should == {p5.id => [p4.id]}
        near_view.gaps.after.should == {p5.id => [p6.id, p7.id]}
      end

      it "returns deleted posts to an admin with show_deleted" do
        coding_horror.admin = true
        near_view = topic_view_near(p3, true)
        near_view.desired_post.should == p3
        near_view.posts.should == [p2, p3, p4]
        near_view.contains_gaps?.should == false
      end

      it "gaps deleted posts by nuked users to an admin" do
        coding_horror.admin = true
        near_view = topic_view_near(p5)
        near_view.desired_post.should == p5
        # note: both p4 and p6 get skipped
        near_view.posts.should == [p2, p3, p5]
        near_view.gaps.before.should == {p5.id => [p4.id]}
        near_view.gaps.after.should == {p5.id => [p6.id, p7.id]}
      end

      it "returns deleted posts by nuked users to an admin with show_deleted" do
        coding_horror.admin = true
        near_view = topic_view_near(p5, true)
        near_view.desired_post.should == p5
        near_view.posts.should == [p4, p5, p6]
        near_view.contains_gaps?.should == false
      end

      context "when 'posts per page' exceeds the number of posts" do
        before { SiteSetting.stubs(:posts_chunksize).returns(100) }

        it 'returns all the posts' do
          near_view = topic_view_near(p5)
          near_view.posts.should == [p1, p2, p3, p5]
          near_view.contains_gaps?.should == false
        end

        it 'gaps deleted posts to admins' do
          coding_horror.admin = true
          near_view = topic_view_near(p5)
          near_view.posts.should == [p1, p2, p3, p5]
          near_view.gaps.before.should == {p5.id => [p4.id]}
          near_view.gaps.after.should == {p5.id => [p6.id, p7.id]}
        end

        it 'returns deleted posts to admins' do
          coding_horror.admin = true
          near_view = topic_view_near(p5, true)
          near_view.posts.should == [p1, p2, p3, p4, p5, p6, p7]
          near_view.contains_gaps?.should == false
        end
      end
    end
  end
end

