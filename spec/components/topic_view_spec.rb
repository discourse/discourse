require 'spec_helper'
require 'topic_view'

describe TopicView do

  let(:topic) { Fabricate(:topic) }
  let(:coding_horror) { Fabricate(:coding_horror) }
  let(:first_poster) { topic.user }
  let!(:p1) { Fabricate(:post, topic: topic, user: first_poster )}
  let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror )}
  let!(:p3) { Fabricate(:post, topic: topic, user: first_poster )}

  let(:topic_view) { TopicView.new(topic.id, coding_horror) }

  it "raises a not found error if the topic doesn't exist" do
    lambda { TopicView.new(1231232, coding_horror) }.should raise_error(Discourse::NotFound)
  end

  it "raises an error if the user can't see the topic" do
    Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
    lambda { topic_view }.should raise_error(Discourse::InvalidAccess)
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

  context '.posts_count' do
    it 'returns the two posters with their counts' do
      topic_view.posts_count.to_a.should =~ [[first_poster.id, 2], [coding_horror.id, 1]]
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

  it 'allows admins to see deleted posts' do
    post_number = p3.post_number
    p3.destroy
    admin = Fabricate(:admin)
    topic_view = TopicView.new(topic.id, admin)
    topic_view.posts.count.should == 3
    topic_view.highest_post_number.should == post_number
  end

  it 'does not allow non admins to see deleted posts' do
    p3.destroy
    topic_view.posts.count.should == 2
  end

  # Sam: disabled for now, we only need this for polls, if we do, roll it into topic
  #  having to walk every post action is not really a good idea
  #
  # context '.voted_in_topic?' do
  #   it "is false when the user hasn't voted" do
  #     topic_view.voted_in_topic?.should be_false
  #   end

  #   it "is true when the user has voted for a post" do
  #     PostAction.act(coding_horror, p1, PostActionType.types[:vote])
  #     topic_view.voted_in_topic?.should be_true
  #   end
  # end

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

  context '.posts' do
    context 'near a post_number' do

      let (:near_topic_view) { TopicView.new(topic.id, coding_horror, post_number: p2.post_number) }

      it 'returns posts around a post number' do
        near_topic_view.posts.should == [p1, p2, p3]
      end

      it 'has a min of the 1st post number' do
        near_topic_view.min.should == p1.post_number
      end

      it 'has a max of the 3rd post number' do
        near_topic_view.max.should == p3.post_number
      end

      it 'is the inital load' do
        near_topic_view.should be_initial_load
      end

    end

    context 'before a post_number' do
      before do
        topic_view.filter_posts_before(p3.post_number)
      end

      it 'returns posts before a post number' do
        topic_view.posts.should == [p2, p1]
      end

      it 'has a min of the 1st post number' do
        topic_view.min.should == p1.post_number
      end

      it 'has a max of the 2nd post number' do
        topic_view.max.should == p2.post_number
      end

      it "isn't the inital load" do
        topic_view.should_not be_initial_load
      end

    end

    context 'after a post_number' do
      before do
        topic_view.filter_posts_after(p1.post_number)
      end

      it 'returns posts after a post number' do
        topic_view.posts.should == [p2, p3]
      end

      it 'has a min of the 1st post number' do
        topic_view.min.should == p1.post_number
      end

      it 'has a max of 3' do
        topic_view.max.should == 3
      end

      it "isn't the inital load" do
        topic_view.should_not be_initial_load
      end
    end
  end

  context 'post range' do
    context 'without gaps' do
      before do
        SiteSetting.stubs(:posts_per_page).returns(20)
        TopicView.any_instance.stubs(:post_numbers).returns((1..50).to_a)
      end

      it 'returns the first a full page if the post number is 1' do
        topic_view.post_range(1).should == [1, 20]
      end

      it 'returns 4 posts above and 16 below' do
        topic_view.post_range(20).should == [15, 34]
      end

      it "returns 20 previous results if we ask for the last post" do
        topic_view.post_range(50).should == [30, 50]
      end

      it "returns 20 previous results we would overlap the last post" do
        topic_view.post_range(40).should == [30, 50]
      end
    end

    context 'with gaps' do
      before do
        SiteSetting.stubs(:posts_per_page).returns(20)

        post_numbers = ((1..20).to_a << [100, 105] << (110..150).to_a).flatten
        TopicView.any_instance.stubs(:post_numbers).returns(post_numbers)
      end

      it "will return posts even if the post required is missing" do
        topic_view.post_range(80).should == [16, 122]
      end

      it "works at the end of gapped post numbers" do
        topic_view.post_range(140).should == [130, 150]
      end

      it "works well past the end of the post numbers" do
        topic_view.post_range(2000).should == [130, 150]
      end

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

