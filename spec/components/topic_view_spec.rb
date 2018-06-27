require 'rails_helper'
require 'topic_view'

describe TopicView do

  let(:topic) { create_topic }
  let(:evil_trout) { Fabricate(:evil_trout) }
  let(:first_poster) { topic.user }

  let(:topic_view) { TopicView.new(topic.id, evil_trout) }

  it "raises a not found error if the topic doesn't exist" do
    expect { TopicView.new(1231232, evil_trout) }.to raise_error(Discourse::NotFound)
  end

  it "accepts a topic or a topic id" do
    expect(TopicView.new(topic, evil_trout).topic).to eq(topic)
    expect(TopicView.new(topic.id, evil_trout).topic).to eq(topic)
  end

  # see also spec/controllers/topics_controller_spec.rb TopicsController::show::permission errors
  it "raises an error if the user can't see the topic" do
    Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
    expect { topic_view }.to raise_error(Discourse::InvalidAccess)
  end

  it "handles deleted topics" do
    admin = Fabricate(:admin)
    topic.trash!(admin)
    expect { TopicView.new(topic.id, Fabricate(:user)) }.to raise_error(Discourse::InvalidAccess)
    expect { TopicView.new(topic.id, admin) }.not_to raise_error
  end

  context "chunk_size" do
    it "returns `chunk_size` by default" do
      expect(TopicView.new(topic.id, evil_trout).chunk_size).to eq(TopicView.chunk_size)
    end

    it "returns `slow_chunk_size` when slow_platform is true" do
      tv = TopicView.new(topic.id, evil_trout, slow_platform: true)
      expect(tv.chunk_size).to eq(TopicView.slow_chunk_size)
    end

    it "returns `print_chunk_size` when print param is true" do
      tv = TopicView.new(topic.id, evil_trout, print: true)
      expect(tv.chunk_size).to eq(TopicView.print_chunk_size)
    end
  end

  context "with a few sample posts" do
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1) }
    let!(:p2) { Fabricate(:post, topic: topic, user: evil_trout, percent_rank: 0.5) }
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0) }

    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }

    it "it can find the best responses" do

      best2 = TopicView.new(topic.id, evil_trout, best: 2)
      expect(best2.posts.count).to eq(2)
      expect(best2.posts[0].id).to eq(p2.id)
      expect(best2.posts[1].id).to eq(p3.id)

      topic.update_status('closed', true, Fabricate(:admin))
      expect(topic.posts.count).to eq(4)

      # should not get the status post
      best = TopicView.new(topic.id, nil, best: 99)
      expect(best.posts.count).to eq(2)
      expect(best.filtered_post_ids.size).to eq(3)
      expect(best.posts.pluck(:id)).to match_array([p2.id, p3.id])

      # should get no results for trust level too low
      best = TopicView.new(topic.id, nil, best: 99, min_trust_level: evil_trout.trust_level + 1)
      expect(best.posts.count).to eq(0)

      # should filter out the posts with a score that is too low
      best = TopicView.new(topic.id, nil, best: 99, min_score: 99)
      expect(best.posts.count).to eq(0)

      # should filter out everything if min replies not met
      best = TopicView.new(topic.id, nil, best: 99, min_replies: 99)
      expect(best.posts.count).to eq(0)

      # should punch through posts if the score is high enough
      p2.update_column(:score, 100)

      best = TopicView.new(topic.id, nil, best: 99, bypass_trust_level_score: 100, min_trust_level: evil_trout.trust_level + 1)
      expect(best.posts.count).to eq(1)

      # 0 means ignore
      best = TopicView.new(topic.id, nil, best: 99, bypass_trust_level_score: 0, min_trust_level: evil_trout.trust_level + 1)
      expect(best.posts.count).to eq(0)

      # If we restrict to posts a moderator liked, return none
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)

      # It doesn't count likes from admins
      PostAction.act(admin, p3, PostActionType.types[:like])
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)

      # It should find the post liked by the moderator
      PostAction.act(moderator, p2, PostActionType.types[:like])
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(1)

    end

    it "raises NotLoggedIn if the user isn't logged in and is trying to view a private message" do
      Topic.any_instance.expects(:private_message?).returns(true)
      expect { TopicView.new(topic.id, nil) }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'log_check_personal_message is enabled' do
      let(:group) { Fabricate(:group) }
      let(:private_message) { Fabricate(:private_message_topic, allowed_groups: [group]) }

      before do
        SiteSetting.log_personal_messages_views = true
        evil_trout.admin = true
      end

      it "logs view if Admin views personal message for other user/group" do
        allowed_user = private_message.topic_allowed_users.first.user
        TopicView.new(private_message.id, allowed_user)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(0)

        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(1)
      end

      it "does not log personal message view for group he belongs to" do
        group.users << evil_trout
        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(0)
      end

      it "does not log personal message view for his own personal message" do
        private_message.allowed_users << evil_trout
        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(0)
      end

      it "does not log personal message view if user can't see the message" do
        expect { TopicView.new(private_message.id, Fabricate(:user)) }.to raise_error(Discourse::InvalidAccess)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(0)
      end

      it "does not log personal message view if there exists a similar log in previous hour" do
        2.times { TopicView.new(private_message.id, evil_trout) }
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(1)

        freeze_time (2.hours.from_now)

        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(2)
      end
    end

    it "provides an absolute url" do
      expect(topic_view.absolute_url).to be_present
    end

    it "provides a summary of the first post" do
      expect(topic_view.summary).to be_present
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
        expect(TopicView.new(1234, user).canonical_path).to eql(path)
        expect(TopicView.new(1234, user, page: 5).canonical_path).to eql("/1234?page=5")
      end

      it "generates a canonical correctly for paged results" do
        expect(TopicView.new(1234, user, post_number: 10 * TopicView.chunk_size)
          .canonical_path).to eql("/1234?page=10")
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
        TopicView.stubs(:chunk_size).returns(2)
      end

      it "should return the next page" do
        expect(TopicView.new(1234, user).next_page).to eql(2)
      end
    end

    context '.post_counts_by_user' do
      it 'returns the two posters with their appropriate counts' do
        Fabricate(:post, topic: topic, user: evil_trout, post_type: Post.types[:whisper])

        expect(topic_view.post_counts_by_user.to_a).to match_array([[first_poster.id, 2], [evil_trout.id, 2]])

        expect(TopicView.new(topic.id, first_poster).post_counts_by_user.to_a).to match_array([[first_poster.id, 2], [evil_trout.id, 1]])
      end

      it "doesn't return counts for posts with authors who have been deleted" do
        p2.user_id = nil
        p2.save!

        expect(topic_view.post_counts_by_user.to_a).to match_array([[first_poster.id, 2]])
      end
    end

    context '.participants' do
      it 'returns the two participants hashed by id' do
        expect(topic_view.participants.to_a).to match_array([[first_poster.id, first_poster], [evil_trout.id, evil_trout]])
      end
    end

    context '.all_post_actions' do
      it 'is blank at first' do
        expect(topic_view.all_post_actions).to be_blank
      end

      it 'returns the like' do
        PostAction.act(evil_trout, p1, PostActionType.types[:like])
        expect(topic_view.all_post_actions[p1.id][PostActionType.types[:like]]).to be_present
      end
    end

    context '.all_active_flags' do
      it 'is blank at first' do
        expect(topic_view.all_active_flags).to be_blank
      end

      it 'returns the active flags' do
        PostAction.act(moderator, p1, PostActionType.types[:off_topic])
        PostAction.act(evil_trout, p1, PostActionType.types[:off_topic])

        expect(topic_view.all_active_flags[p1.id][PostActionType.types[:off_topic]].count).to eq(2)
      end

      it 'returns only the active flags' do
        PostAction.act(moderator, p1, PostActionType.types[:off_topic])
        PostAction.act(evil_trout, p1, PostActionType.types[:off_topic])

        PostAction.defer_flags!(p1, moderator)

        expect(topic_view.all_active_flags[p1.id]).to eq(nil)
      end
    end

    context '.read?' do
      it 'tracks correctly' do
        # anon is assumed to have read everything
        expect(TopicView.new(topic.id).read?(1)).to eq(true)

        # random user has nothing
        expect(topic_view.read?(1)).to eq(false)

        evil_trout.created_at = 2.days.ago

        # a real user that just read it should have it marked
        PostTiming.process_timings(evil_trout, topic.id, 1, [[1, 1000]])
        expect(TopicView.new(topic.id, evil_trout).read?(1)).to eq(true)
        expect(TopicView.new(topic.id, evil_trout).topic_user).to be_present
      end
    end

    context '.topic_user' do
      it 'returns nil when there is no user' do
        expect(TopicView.new(topic.id, nil).topic_user).to be_blank
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
        expect(recent_posts.count).to eq(25)

        # ordering
        expect(recent_posts.include?(p1)).to eq(false)
        expect(recent_posts.include?(p3)).to eq(true)
        expect(recent_posts.first.created_at).to be > recent_posts.last.created_at
      end
    end

  end

  context 'whispers' do
    it "handles their visibility properly" do
      p1 = Fabricate(:post, topic: topic, user: evil_trout)
      p2 = Fabricate(:post, topic: topic, user: evil_trout, post_type: Post.types[:whisper])
      p3 = Fabricate(:post, topic: topic, user: evil_trout)

      ch_posts = TopicView.new(topic.id, evil_trout).posts
      expect(ch_posts.map(&:id)).to eq([p1.id, p2.id, p3.id])

      anon_posts = TopicView.new(topic.id).posts
      expect(anon_posts.map(&:id)).to eq([p1.id, p3.id])

      admin_posts = TopicView.new(topic.id, Fabricate(:moderator)).posts
      expect(admin_posts.map(&:id)).to eq([p1.id, p2.id, p3.id])
    end
  end

  context '.posts' do

    # Create the posts in a different order than the sort_order
    let!(:p5) { Fabricate(:post, topic: topic, user: evil_trout) }
    let!(:p2) { Fabricate(:post, topic: topic, user: evil_trout) }
    let!(:p6) { Fabricate(:post, topic: topic, user: Fabricate(:user), deleted_at: Time.now) }
    let!(:p4) { Fabricate(:post, topic: topic, user: evil_trout, deleted_at: Time.now) }
    let!(:p1) { Fabricate(:post, topic: topic, user: first_poster) }
    let!(:p7) { Fabricate(:post, topic: topic, user: evil_trout, deleted_at: Time.now) }
    let!(:p3) { Fabricate(:post, topic: topic, user: first_poster) }

    before do
      TopicView.stubs(:chunk_size).returns(3)

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
        expect(topic_view.contains_gaps?).to eq(false)
        # contains contains_gaps when filtered by username" do
        expect(TopicView.new(topic.id, evil_trout, username_filters: ['eviltrout']).contains_gaps?).to eq(true)
        # contains contains_gaps when filtered by summary
        expect(TopicView.new(topic.id, evil_trout, filter: 'summary').contains_gaps?).to eq(true)
        # contains contains_gaps when filtered by best
        expect(TopicView.new(topic.id, evil_trout, best: 5).contains_gaps?).to eq(true)
      end
    end

    it "#restricts to correct topic" do
      t2 = Fabricate(:topic)

      category = Fabricate(:category, name: "my test")
      category.set_permissions(Group[:admins] => :full)
      category.save

      topic.category_id = category.id
      topic.save!

      expect {
        TopicView.new(topic.id, evil_trout).posts.count
      }.to raise_error(Discourse::InvalidAccess)

      expect(TopicView.new(t2.id, evil_trout, post_ids: [p1.id, p2.id]).posts.count).to eq(0)

    end

    describe '#filter_posts_paged' do
      before { TopicView.stubs(:chunk_size).returns(2) }

      it 'returns correct posts for all pages' do
        expect(topic_view.filter_posts_paged(1)).to eq([p1, p2])
        expect(topic_view.filter_posts_paged(2)).to eq([p3, p5])
        expect(topic_view.filter_posts_paged(3)).to eq([])
        expect(topic_view.filter_posts_paged(100)).to eq([])
      end
    end

    describe "filter_posts_near" do

      def topic_view_near(post, show_deleted = false)
        TopicView.new(topic.id, evil_trout, post_number: post.post_number, show_deleted: show_deleted)
      end

      it "snaps to the lower boundary" do
        near_view = topic_view_near(p1)
        expect(near_view.desired_post).to eq(p1)
        expect(near_view.posts).to eq([p1, p2, p3])
        expect(near_view.contains_gaps?).to eq(false)
      end

      it "snaps to the upper boundary" do
        near_view = topic_view_near(p5)
        expect(near_view.desired_post).to eq(p5)
        expect(near_view.posts).to eq([p2, p3, p5])
        expect(near_view.contains_gaps?).to eq(false)
      end

      it "returns the posts in the middle" do
        near_view = topic_view_near(p2)
        expect(near_view.desired_post).to eq(p2)
        expect(near_view.posts).to eq([p1, p2, p3])
        expect(near_view.contains_gaps?).to eq(false)
      end

      it "gaps deleted posts to an admin" do
        evil_trout.admin = true
        near_view = topic_view_near(p3)
        expect(near_view.desired_post).to eq(p3)
        expect(near_view.posts).to eq([p2, p3, p5])
        expect(near_view.gaps.before).to eq(p5.id => [p4.id])
        expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
      end

      it "returns deleted posts to an admin with show_deleted" do
        evil_trout.admin = true
        near_view = topic_view_near(p3, true)
        expect(near_view.desired_post).to eq(p3)
        expect(near_view.posts).to eq([p2, p3, p4])
        expect(near_view.contains_gaps?).to eq(false)
      end

      it "gaps deleted posts by nuked users to an admin" do
        evil_trout.admin = true
        near_view = topic_view_near(p5)
        expect(near_view.desired_post).to eq(p5)
        # note: both p4 and p6 get skipped
        expect(near_view.posts).to eq([p2, p3, p5])
        expect(near_view.gaps.before).to eq(p5.id => [p4.id])
        expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
      end

      it "returns deleted posts by nuked users to an admin with show_deleted" do
        evil_trout.admin = true
        near_view = topic_view_near(p5, true)
        expect(near_view.desired_post).to eq(p5)
        expect(near_view.posts).to eq([p4, p5, p6])
        expect(near_view.contains_gaps?).to eq(false)
      end

      context "when 'posts per page' exceeds the number of posts" do
        before { TopicView.stubs(:chunk_size).returns(100) }

        it 'returns all the posts' do
          near_view = topic_view_near(p5)
          expect(near_view.posts).to eq([p1, p2, p3, p5])
          expect(near_view.contains_gaps?).to eq(false)
        end

        it 'gaps deleted posts to admins' do
          evil_trout.admin = true
          near_view = topic_view_near(p5)
          expect(near_view.posts).to eq([p1, p2, p3, p5])
          expect(near_view.gaps.before).to eq(p5.id => [p4.id])
          expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
        end

        it 'returns deleted posts to admins' do
          evil_trout.admin = true
          near_view = topic_view_near(p5, true)
          expect(near_view.posts).to eq([p1, p2, p3, p4, p5, p6, p7])
          expect(near_view.contains_gaps?).to eq(false)
        end
      end
    end
  end

  context "page_title" do
    let(:tag1) { Fabricate(:tag) }
    let(:tag2) { Fabricate(:tag, topic_count: 2) }

    subject { TopicView.new(topic.id, evil_trout).page_title }

    context "uncategorized topic" do
      context "topic_page_title_includes_category is false" do
        before { SiteSetting.topic_page_title_includes_category = false }
        it { should eq(topic.title) }
      end

      context "topic_page_title_includes_category is true" do
        before { SiteSetting.topic_page_title_includes_category = true }
        it { should eq(topic.title) }

        context "tagged topic" do
          before { topic.tags << [tag1, tag2] }

          context "tagging enabled" do
            before { SiteSetting.tagging_enabled = true }

            it { should start_with(topic.title) }
            it { should_not include(tag1.name) }
            it { should end_with(tag2.name) } # tag2 has higher topic count
          end

          context "tagging disabled" do
            before { SiteSetting.tagging_enabled = false }

            it { should start_with(topic.title) }
            it { should_not include(tag1.name) }
            it { should_not include(tag2.name) }
          end
        end
      end
    end

    context "categorized topic" do
      let(:category) { Fabricate(:category) }

      before { topic.update_attributes(category_id: category.id) }

      context "topic_page_title_includes_category is false" do
        before { SiteSetting.topic_page_title_includes_category = false }
        it { should eq(topic.title) }
      end

      context "topic_page_title_includes_category is true" do
        before { SiteSetting.topic_page_title_includes_category = true }
        it { should start_with(topic.title) }
        it { should end_with(category.name) }

        context "tagged topic" do
          before do
            SiteSetting.tagging_enabled = true
            topic.tags << [tag1, tag2]
          end

          it { should start_with(topic.title) }
          it { should end_with(category.name) }
          it { should_not include(tag1.name) }
          it { should_not include(tag2.name) }
        end
      end
    end
  end

  describe '#filtered_post_stream' do
    let!(:post) { Fabricate(:post, topic: topic, user: first_poster) }
    let!(:post2) { Fabricate(:post, topic: topic, user: evil_trout) }
    let!(:post3) { Fabricate(:post, topic: topic, user: first_poster) }

    it 'should return the right columns' do
      expect(topic_view.filtered_post_stream).to eq([
        [post.id, 0],
        [post2.id, 0],
        [post3.id, 0]
      ])
    end

    describe 'for mega topics' do
      it 'should return the right columns' do
        begin
          original_const = TopicView::MEGA_TOPIC_POSTS_COUNT
          TopicView.send(:remove_const, "MEGA_TOPIC_POSTS_COUNT")
          TopicView.const_set("MEGA_TOPIC_POSTS_COUNT", 2)

          expect(topic_view.filtered_post_stream).to eq([
            post.id,
            post2.id,
            post3.id
          ])
        ensure
          TopicView.send(:remove_const, "MEGA_TOPIC_POSTS_COUNT")
          TopicView.const_set("MEGA_TOPIC_POSTS_COUNT", original_const)
        end
      end
    end
  end

  describe '#filtered_post_id' do
    it 'should return the right id' do
      post = Fabricate(:post, topic: topic)

      expect(topic_view.filtered_post_id(nil)).to eq(nil)
      expect(topic_view.filtered_post_id(post.post_number)).to eq(post.id)
    end
  end
end
