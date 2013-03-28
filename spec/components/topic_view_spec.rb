require 'spec_helper'
require 'topic_view'

describe TopicView do

  let(:topic) { Fabricate(:topic) }
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

  context "with a few sample posts" do
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1 )}
    let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror, percent_rank: 0.5 )}
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0 )}

    it "it can the best 2 responses" do
      best2 = TopicView.new(topic.id, nil, best: 2)
      best2.posts.count.should == 2
      best2.posts[0].id.should == p2.id
      best2.posts[1].id.should == p3.id
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
        topic.expects(:relative_url).returns(path)
        described_class.any_instance.expects(:find_topic).with(1234).returns(topic)
      end

      context "without a post number" do
        context "without a page" do
          it "generates a canonical path for a topic" do
            described_class.new(1234, user).canonical_path.should eql(path)
          end
        end

        context "with a page" do
          let(:path_with_page) { "/1234?page=5" }

          it "generates a canonical path for a topic" do
            described_class.new(1234, user, page: 5).canonical_path.should eql(path_with_page)
          end
        end
      end
      context "with a post number" do
        let(:path_with_page) { "/1234?page=10" }
        before { SiteSetting.stubs(:posts_per_page).returns(5) }

        it "generates a canonical path for a topic" do
          described_class.new(1234, user, post_number: 50).canonical_path.should eql(path_with_page)
        end
      end
    end

    describe "#next_page" do
      let(:posts) { [stub(post_number: 1), stub(post_number: 2)] }
      let(:topic) do
        topic = Fabricate(:topic)
        topic.stubs(:posts).returns(posts)
        topic.stubs(:highest_post_number).returns(5)
        topic
      end
      let(:user) { Fabricate(:user) }

      before do
        described_class.any_instance.expects(:find_topic).with(1234).returns(topic)
        described_class.any_instance.stubs(:filter_posts)
        SiteSetting.stubs(:posts_per_page).returns(2)
      end

      it "should return the next page" do
        described_class.new(1234, user).next_page.should eql(1)
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

    context '.post_action_visibility' do
      it "is allows users to see likes" do
        topic_view.post_action_visibility.include?(PostActionType.types[:like]).should be_true
      end
    end

    context '.read?' do
      it 'is unread with no logged in user' do
        TopicView.new(topic.id).read?(1).should be_false
      end

      it 'makes posts as unread by default' do
        topic_view.read?(1).should be_false
      end

      it 'knows a post is read when it has a PostTiming' do
        PostTiming.create(topic: topic, user: coding_horror, post_number: 1, msecs: 1000)
        topic_view.read?(1).should be_true
      end
    end

    context '.topic_user' do
      it 'returns nil when there is no user' do
        TopicView.new(topic.id, nil).topic_user.should be_blank
      end

      it 'returns a record once the user has some data' do
        TopicView.new(topic.id, coding_horror).topic_user.should be_present
      end
    end

    context '#recent_posts' do
      before do
        24.times do # our let()s have already created 3
          Fabricate(:post, topic: topic, user: first_poster)
        end
      end
      it 'returns at most 25 recent posts ordered newest first' do
        recent_posts = topic_view.recent_posts

        # count
        recent_posts.count.should == 25

        # ordering
        recent_posts.include?(p1).should be_false
        recent_posts.include?(p3).should be_true
        recent_posts.first.created_at.should > recent_posts.last.created_at
      end
    end

  end

  context '.posts' do

    # Create the posts in a different order than the sort_order
    let!(:p5) { Fabricate(:post, topic: topic, user: coding_horror)}
    let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror)}
    let!(:p4) { Fabricate(:post, topic: topic, user: coding_horror, deleted_at: Time.now)}
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster)}
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster)}

    before do
      SiteSetting.stubs(:posts_per_page).returns(3)

      # Update them to the sort order we're checking for
      [p1, p2, p3, p4, p5].each_with_index do |p, idx|
        p.sort_order = idx + 1
        p.save
      end
    end

    describe "filter_posts_after" do
      it "returns undeleted posts after a post" do
        topic_view.filter_posts_after(p1.post_number).should == [p2, p3, p5]
        topic_view.should_not be_initial_load
        topic_view.index_offset.should == 1
        topic_view.index_reverse.should be_false
      end

      it "clips to the end boundary" do
        topic_view.filter_posts_after(p2.post_number).should == [p3, p5]
        topic_view.index_offset.should == 2
        topic_view.index_reverse.should be_false
      end

      it "returns nothing after the last post" do
        topic_view.filter_posts_after(p5.post_number).should be_blank
      end

      it "returns nothing after an invalid post number" do
        topic_view.filter_posts_after(1000).should be_blank
      end

      it "returns deleted posts to an admin" do
        coding_horror.admin = true
        topic_view.filter_posts_after(p1.post_number).should == [p2, p3, p4]
        topic_view.index_offset.should == 1
        topic_view.index_reverse.should be_false
      end
    end

    describe "fitler_posts_before" do
      it "returns undeleted posts before a post" do
        topic_view.filter_posts_before(p5.post_number).should == [p3, p2, p1]
        topic_view.should_not be_initial_load
        topic_view.index_offset.should == 3
        topic_view.index_reverse.should be_true
      end

      it "clips to the beginning boundary" do
        topic_view.filter_posts_before(p3.post_number).should == [p2, p1]
        topic_view.index_offset.should == 2
        topic_view.index_reverse.should be_true
      end

      it "returns nothing before the first post" do
        topic_view.filter_posts_before(p1.post_number).should be_blank
      end

      it "returns nothing before an invalid post number" do
        topic_view.filter_posts_before(-10).should be_blank
        topic_view.filter_posts_before(1000).should be_blank
      end

      it "returns deleted posts to an admin" do
        coding_horror.admin = true
        topic_view.filter_posts_before(p5.post_number).should == [p4, p3, p2]
        topic_view.index_offset.should == 4
        topic_view.index_reverse.should be_true
      end
    end

    describe "filter_posts_near" do

      def topic_view_near(post)
        TopicView.new(topic.id, coding_horror, post_number: post.post_number)
      end

      it "snaps to the lower boundary" do
        near_view = topic_view_near(p1)
        near_view.posts.should == [p1, p2, p3]
        near_view.index_offset.should == 0
        near_view.index_reverse.should be_false
      end

      it "snaps to the upper boundary" do
        near_view = topic_view_near(p5)
        near_view.posts.should == [p2, p3, p5]
        near_view.index_offset.should == 1
        near_view.index_reverse.should be_false
      end

      it "returns the posts in the middle" do
        near_view = topic_view_near(p2)
        near_view.posts.should == [p1, p2, p3]
        near_view.index_offset.should == 0
        near_view.index_reverse.should be_false
      end

      it "returns deleted posts to an admin" do
        coding_horror.admin = true
        near_view = topic_view_near(p3)
        near_view.posts.should == [p2, p3, p4]
        near_view.index_offset.should == 1
        near_view.index_reverse.should be_false
      end
    end

  end

end

