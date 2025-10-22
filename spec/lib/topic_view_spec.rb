# frozen_string_literal: true

require "topic_view"

RSpec.describe TopicView do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:admin)
  fab!(:topic)
  fab!(:evil_trout)
  fab!(:first_poster) { topic.user }
  fab!(:anonymous)

  let(:topic_view) { TopicView.new(topic.id, evil_trout) }

  describe "preload" do
    it "allows preloading of data" do
      preloaded_topic_view = nil
      preloader = lambda { |view| preloaded_topic_view = view }

      TopicView.on_preload(&preloader)

      expect(preloaded_topic_view).to eq(nil)
      topic_view
      expect(preloaded_topic_view).to eq(topic_view)

      TopicView.cancel_preload(&preloader)
    end
  end

  it "raises a not found error if the topic doesn't exist" do
    expect { TopicView.new(1_231_232, evil_trout) }.to raise_error(Discourse::NotFound)
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
    topic.trash!(admin)
    expect { TopicView.new(topic.id, user) }.to raise_error(Discourse::InvalidAccess)
    expect { TopicView.new(topic.id, admin) }.not_to raise_error
  end

  describe "filter options" do
    fab!(:p0) { Fabricate(:post, topic: topic) }
    fab!(:p1) { Fabricate(:post, topic: topic, post_type: Post.types[:moderator_action]) }
    fab!(:p2) { Fabricate(:post, topic: topic, post_type: Post.types[:small_action]) }

    it "omits moderator actions and small posts when only_regular is set" do
      tv = TopicView.new(topic.id, nil)
      expect(tv.filtered_post_ids).to eq([p0.id, p1.id, p2.id])

      tv = TopicView.new(topic.id, nil, only_regular: true)
      expect(tv.filtered_post_ids).to eq([p0.id])
    end

    it "omits the first post when exclude_first is set" do
      tv = TopicView.new(topic.id, nil, exclude_first: true)
      expect(tv.filtered_post_ids).to eq([p0.id, p1.id, p2.id])
    end
  end

  describe "custom filters" do
    fab!(:p0) { Fabricate(:post, topic: topic) }
    fab!(:p1) { Fabricate(:post, topic: topic, wiki: true) }

    after { TopicView.custom_filters.clear }

    it "allows to register custom filters" do
      tv = TopicView.new(topic.id, evil_trout, { filter: "wiki" })
      expect(tv.filter_posts({ filter: "wiki" })).to eq([p0, p1])

      TopicView.add_custom_filter("wiki") { |posts, topic_view| posts.where(wiki: true) }

      tv = TopicView.new(topic.id, evil_trout, { filter: "wiki" })
      expect(tv.filter_posts).to eq([p1])

      tv = TopicView.new(topic.id, evil_trout, { filter: "whatever" })
      expect(tv.filter_posts).to eq([p0, p1])
    end
  end

  describe "setup_filtered_posts" do
    describe "filters posts with ignored users" do
      fab!(:ignored_user) { Fabricate(:ignored_user, user: evil_trout, ignored_user: user) }
      let!(:post) { Fabricate(:post, topic: topic, user: first_poster) }
      let!(:post2) { Fabricate(:post, topic: topic, user: evil_trout) }
      let!(:post3) { Fabricate(:post, topic: topic, user: user) }

      it "filters out ignored user posts" do
        tv = TopicView.new(topic.id, evil_trout)
        expect(tv.filtered_post_ids).to eq([post.id, post2.id])
      end

      it "returns nil for next_page" do
        tv = TopicView.new(topic.id, evil_trout)
        expect(tv.next_page).to eq(nil)
      end

      context "when an ignored user made the original post" do
        let!(:post) { Fabricate(:post, topic: topic, user: user) }

        it "filters out ignored user posts only" do
          tv = TopicView.new(topic.id, evil_trout)
          expect(tv.filtered_post_ids).to eq([post.id, post2.id])
        end
      end

      context "when an anonymous user made a post" do
        let!(:post4) { Fabricate(:post, topic: topic, user: anonymous) }

        it "filters out ignored user posts only" do
          tv = TopicView.new(topic.id, evil_trout)
          expect(tv.filtered_post_ids).to eq([post.id, post2.id, post4.id])
        end
      end

      context "when an anonymous (non signed-in) user is viewing a Topic" do
        let!(:post4) { Fabricate(:post, topic: topic, user: anonymous) }

        it "filters out ignored user posts only" do
          tv = TopicView.new(topic.id, nil)
          expect(tv.filtered_post_ids).to eq([post.id, post2.id, post3.id, post4.id])
        end
      end

      context "when a staff user is ignored" do
        let!(:admin) { Fabricate(:user, admin: true) }
        let!(:admin_ignored_user) do
          Fabricate(:ignored_user, user: evil_trout, ignored_user: admin)
        end
        let!(:post4) { Fabricate(:post, topic: topic, user: admin) }

        it "filters out ignored user excluding the staff user" do
          tv = TopicView.new(topic.id, evil_trout)
          expect(tv.filtered_post_ids).to eq([post.id, post2.id, post4.id])
        end
      end
    end
  end

  describe "chunk_size" do
    it "returns `chunk_size` by default" do
      expect(TopicView.new(topic.id, evil_trout).chunk_size).to eq(TopicView.chunk_size)
    end

    it "returns `print_chunk_size` when print param is true" do
      tv = TopicView.new(topic.id, evil_trout, print: true)
      expect(tv.chunk_size).to eq(TopicView.print_chunk_size)
    end
  end

  context "with a few sample posts" do
    fab!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1) }
    fab!(:p2) { Fabricate(:post, topic: topic, user: evil_trout, percent_rank: 0.5) }
    fab!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0) }

    it "it can find the best responses" do
      best2 = TopicView.new(topic.id, evil_trout, best: 2)
      expect(best2.posts.count).to eq(2)
      expect(best2.posts[0].id).to eq(p2.id)
      expect(best2.posts[1].id).to eq(p3.id)

      topic.update_status("closed", true, admin)
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

      best =
        TopicView.new(
          topic.id,
          nil,
          best: 99,
          bypass_trust_level_score: 100,
          min_trust_level: evil_trout.trust_level + 1,
        )
      expect(best.posts.count).to eq(1)

      # 0 means ignore
      best =
        TopicView.new(
          topic.id,
          nil,
          best: 99,
          bypass_trust_level_score: 0,
          min_trust_level: evil_trout.trust_level + 1,
        )
      expect(best.posts.count).to eq(0)

      # If we restrict to posts a moderator liked, return none
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)

      # It doesn't count likes from admins
      PostActionCreator.like(admin, p3)
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)

      # It should find the post liked by the moderator
      PostActionCreator.like(moderator, p2)
      best = TopicView.new(topic.id, nil, best: 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(1)
    end

    it "raises NotLoggedIn if the user isn't logged in and is trying to view a private message" do
      Topic.any_instance.expects(:private_message?).returns(true)
      expect { TopicView.new(topic.id, nil) }.to raise_error(Discourse::NotLoggedIn)
    end

    context "when log_check_personal_message is enabled" do
      fab!(:group)
      fab!(:private_message) { Fabricate(:private_message_topic, allowed_groups: [group]) }

      before do
        SiteSetting.log_personal_messages_views = true
        evil_trout.admin = true
      end

      it "logs view if Admin views personal message for other user/group" do
        allowed_user = private_message.topic_allowed_users.first.user
        TopicView.new(private_message.id, allowed_user)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          0,
        )

        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          1,
        )
      end

      it "does not log personal message view for group he belongs to" do
        group.users << evil_trout
        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          0,
        )
      end

      it "does not log personal message view for his own personal message" do
        private_message.allowed_users << evil_trout
        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          0,
        )
      end

      it "does not log personal message view if user can't see the message" do
        expect { TopicView.new(private_message.id, user) }.to raise_error(Discourse::InvalidAccess)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          0,
        )
      end

      it "does not log personal message view if there exists a similar log in previous hour" do
        2.times { TopicView.new(private_message.id, evil_trout) }
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          1,
        )

        freeze_time(2.hours.from_now)

        TopicView.new(private_message.id, evil_trout)
        expect(UserHistory.where(action: UserHistory.actions[:check_personal_message]).count).to eq(
          2,
        )
      end
    end

    it "provides an absolute url" do
      expect(topic_view.absolute_url).to eq("http://test.localhost/t/#{topic.slug}/#{topic.id}")
    end

    context "with subfolder" do
      it "provides the correct absolute url" do
        set_subfolder "/forum"
        expect(topic_view.absolute_url).to eq(
          "http://test.localhost/forum/t/#{topic.slug}/#{topic.id}",
        )
      end
    end

    it "provides a summary of the first post" do
      expect(topic_view.summary).to be_present
    end

    describe "#get_canonical_path" do
      fab!(:topic)
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
        5.times { |i| Fabricate(:post, post_number: i + 1, topic: topic) }

        expect(TopicView.new(1234, user, post_number: 5, limit: 2).canonical_path).to eql(
          "/1234?page=3",
        )
      end

      it "generates canonical path correctly by skipping whisper posts" do
        2.times { |i| Fabricate(:post, post_number: i + 1, topic: topic) }
        2.times { |i| Fabricate(:whisper, post_number: i + 3, topic: topic) }
        Fabricate(:post, post_number: 5, topic: topic)

        expect(TopicView.new(1234, user, post_number: 5, limit: 2).canonical_path).to eql(
          "/1234?page=2",
        )
      end

      it "generates canonical path correctly for mega topics" do
        2.times { |i| Fabricate(:post, post_number: i + 1, topic: topic) }
        2.times { |i| Fabricate(:whisper, post_number: i + 3, topic: topic) }
        Fabricate(:post, post_number: 5, topic: topic)

        expect(
          TopicView.new(1234, user, post_number: 5, limit: 2, is_mega_topic: true).canonical_path,
        ).to eql("/1234?page=3")
      end
    end

    describe "#next_page" do
      let!(:post) { Fabricate(:post, topic: topic, user: user) }
      let!(:post2) { Fabricate(:post, topic: topic, user: user) }
      let!(:post3) { Fabricate(:post, topic: topic, user: user) }
      let!(:post4) { Fabricate(:post, topic: topic, user: user) }
      let!(:post5) { Fabricate(:post, topic: topic, user: user) }

      before { TopicView.stubs(:chunk_size).returns(2) }

      it "should return the next page" do
        expect(TopicView.new(topic.id, user, { post_number: post.post_number }).next_page).to eql(3)
      end
    end

    describe ".post_counts_by_user" do
      it "returns the two posters with their appropriate counts" do
        SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
        Fabricate(:post, topic: topic, user: evil_trout, post_type: Post.types[:whisper])
        # Should not be counted
        Fabricate(
          :post,
          topic: topic,
          user: evil_trout,
          post_type: Post.types[:whisper],
          action_code: "assign",
        )

        expect(TopicView.new(topic.id, admin).post_counts_by_user.to_a).to match_array(
          [[first_poster.id, 2], [evil_trout.id, 2]],
        )

        expect(TopicView.new(topic.id, first_poster).post_counts_by_user.to_a).to match_array(
          [[first_poster.id, 2], [evil_trout.id, 1]],
        )
      end

      it "doesn't return counts for posts with authors who have been deleted" do
        p2.user_id = nil
        p2.save!

        expect(topic_view.post_counts_by_user.to_a).to match_array([[first_poster.id, 2]])
      end
    end

    describe ".participants" do
      it "returns the two participants hashed by id" do
        expect(topic_view.participants.to_a).to match_array(
          [[first_poster.id, first_poster], [evil_trout.id, evil_trout]],
        )
      end
    end

    describe ".all_post_actions" do
      it "is blank at first" do
        expect(topic_view.all_post_actions).to be_blank
      end

      it "returns the like" do
        PostActionCreator.like(evil_trout, p1)
        expect(topic_view.all_post_actions[p1.id][PostActionType.types[:like]]).to be_present
      end
    end

    describe ".read?" do
      it "tracks correctly" do
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

    describe "#bookmarks" do
      let!(:user) { Fabricate(:user) }
      let!(:bookmark1) do
        Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user)
      end
      let!(:bookmark2) do
        Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user)
      end
      let!(:bookmark3) { Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic)) }

      it "returns all the bookmarks in the topic for a user" do
        expect(TopicView.new(topic.id, user).bookmarks.pluck(:id)).to match_array(
          [bookmark1.id, bookmark2.id],
        )
      end

      it "returns [] for anon users" do
        expect(TopicView.new(topic.id, nil).bookmarks.pluck(:id)).to eq([])
      end
    end

    describe "#bookmarks" do
      let!(:user) { Fabricate(:user) }
      let!(:bookmark1) do
        Fabricate(:bookmark_next_business_day_reminder, bookmarkable: topic.first_post, user: user)
      end
      let!(:bookmark2) do
        Fabricate(
          :bookmark_next_business_day_reminder,
          bookmarkable: topic.posts.order(:post_number)[1],
          user: user,
        )
      end

      it "gets the first post bookmark reminder at for the user" do
        topic_view = TopicView.new(topic.id, user)

        first, second = topic_view.bookmarks.sort_by(&:id)
        expect(first[:bookmarkable_id]).to eq(bookmark1.bookmarkable_id)
        expect(first[:reminder_at]).to eq_time(bookmark1.reminder_at)
        expect(second[:bookmarkable_id]).to eq(bookmark2.bookmarkable_id)
        expect(second[:reminder_at]).to eq_time(bookmark2.reminder_at)
      end

      context "when the topic is deleted" do
        it "returns []" do
          topic_view = TopicView.new(topic, user)
          expect(topic_view.bookmarks).to match_array([bookmark1, bookmark2])
          PostDestroyer.new(Fabricate(:admin), topic.first_post).destroy
          topic.reload
          topic_view.instance_variable_set(:@bookmarks, nil)
          expect(topic_view.bookmarks).to eq([])
        end
      end

      context "when one of the posts is deleted" do
        it "does not return that post's bookmark" do
          topic_view = TopicView.new(topic, user)
          PostDestroyer.new(Fabricate(:admin), topic.posts.second).destroy
          topic.reload

          expect(topic_view.bookmarks.length).to eq(1)
          first = topic_view.bookmarks.first
          expect(first[:bookmarkable_id]).to eq(bookmark1.bookmarkable_id)
          expect(first[:reminder_at]).to eq_time(bookmark1.reminder_at)
        end
      end
    end

    describe ".topic_user" do
      it "returns nil when there is no user" do
        expect(TopicView.new(topic.id, nil).topic_user).to be_blank
      end
    end

    describe "#recent_posts" do
      before do
        24.times do |t| # our let()s have already created 3
          Fabricate(:post, topic: topic, user: first_poster, created_at: t.seconds.from_now)
        end
      end

      it "returns at most 25 recent posts ordered newest first" do
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

  describe "whispers" do
    it "handles their visibility properly" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      p1 = Fabricate(:post, topic: topic, user: evil_trout)
      p2 = Fabricate(:post, topic: topic, user: evil_trout, post_type: Post.types[:whisper])
      p3 = Fabricate(:post, topic: topic, user: evil_trout)

      ch_posts = TopicView.new(topic.id, evil_trout).posts
      expect(ch_posts.map(&:id)).to eq([p1.id, p3.id])

      anon_posts = TopicView.new(topic.id).posts
      expect(anon_posts.map(&:id)).to eq([p1.id, p3.id])

      admin_posts = TopicView.new(topic.id, moderator).posts
      expect(admin_posts.map(&:id)).to eq([p1.id, p2.id, p3.id])
    end
  end

  describe "#posts" do
    # Create the posts in a different order than the sort_order
    let!(:p5) { Fabricate(:post, topic: topic, user: evil_trout) }
    let!(:p2) { Fabricate(:post, topic: topic, user: evil_trout) }
    let!(:p6) { Fabricate(:post, topic: topic, user: user, deleted_at: Time.now) }
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
        expect(
          TopicView.new(topic.id, evil_trout, username_filters: ["eviltrout"]).contains_gaps?,
        ).to eq(true)
        # contains contains_gaps when filtered by summary
        expect(TopicView.new(topic.id, evil_trout, filter: "summary").contains_gaps?).to eq(true)
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

      expect { TopicView.new(topic.id, evil_trout).posts.count }.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(TopicView.new(t2.id, evil_trout, post_ids: [p1.id, p2.id]).posts.count).to eq(0)
    end

    describe "#filter_posts_paged" do
      before { TopicView.stubs(:chunk_size).returns(2) }

      it "returns correct posts for all pages" do
        expect(topic_view.filter_posts_paged(1)).to eq([p1, p2])
        expect(topic_view.filter_posts_paged(2)).to eq([p3, p5])
        expect(topic_view.filter_posts_paged(3)).to eq([])
        expect(topic_view.filter_posts_paged(100)).to eq([])
      end
    end

    describe "#filter_posts_by_post_number" do
      def create_topic_view(post_number)
        TopicView.new(topic.id, evil_trout, filter_post_number: post_number, asc: asc)
      end

      describe "ascending" do
        let(:asc) { true }

        it "should return the right posts" do
          topic_view = create_topic_view(p3.post_number)

          expect(topic_view.posts).to eq([p5])

          topic_view = create_topic_view(p6.post_number)
          expect(topic_view.posts).to eq([])
        end
      end

      describe "descending" do
        let(:asc) { false }

        it "should return the right posts" do
          topic_view = create_topic_view(p7.post_number)

          expect(topic_view.posts).to eq([p5, p3, p2])

          topic_view = create_topic_view(p2.post_number)

          expect(topic_view.posts).to eq([p1])
        end
      end
    end

    describe "filter_posts_near" do
      def topic_view_near(post, user = evil_trout, show_deleted: false)
        TopicView.new(topic.id, user, post_number: post.post_number, show_deleted: show_deleted)
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

      describe "when post_number is too large" do
        it "snaps to the lower boundary" do
          near_view = TopicView.new(topic.id, evil_trout, post_number: 99_999_999)

          expect(near_view.desired_post).to eq(p2)
          expect(near_view.posts).to eq([p2, p3, p5])
          expect(near_view.contains_gaps?).to eq(false)
        end
      end

      it "gaps deleted posts to an admin" do
        near_view = topic_view_near(p3, admin)
        expect(near_view.desired_post).to eq(p3)
        expect(near_view.posts).to eq([p2, p3, p5])
        expect(near_view.gaps.before).to eq(p5.id => [p4.id])
        expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
      end

      it "returns deleted posts to an admin with show_deleted" do
        near_view = topic_view_near(p3, admin, show_deleted: true)
        expect(near_view.desired_post).to eq(p3)
        expect(near_view.posts).to eq([p2, p3, p4])
        expect(near_view.contains_gaps?).to eq(false)
      end

      it "gaps deleted posts by nuked users to an admin" do
        near_view = topic_view_near(p5, admin)
        expect(near_view.desired_post).to eq(p5)
        # note: both p4 and p6 get skipped
        expect(near_view.posts).to eq([p2, p3, p5])
        expect(near_view.gaps.before).to eq(p5.id => [p4.id])
        expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
      end

      it "returns deleted posts by nuked users to an admin with show_deleted" do
        near_view = topic_view_near(p5, admin, show_deleted: true)
        expect(near_view.desired_post).to eq(p5)
        expect(near_view.posts).to eq([p4, p5, p6])
        expect(near_view.contains_gaps?).to eq(false)
      end

      context "when 'posts per page' exceeds the number of posts" do
        before { TopicView.stubs(:chunk_size).returns(100) }

        it "returns all the posts" do
          near_view = topic_view_near(p5)
          expect(near_view.posts).to eq([p1, p2, p3, p5])
          expect(near_view.contains_gaps?).to eq(false)
        end

        it "gaps deleted posts to admins" do
          near_view = topic_view_near(p5, admin)
          expect(near_view.posts).to eq([p1, p2, p3, p5])
          expect(near_view.gaps.before).to eq(p5.id => [p4.id])
          expect(near_view.gaps.after).to eq(p5.id => [p6.id, p7.id])
        end

        it "returns deleted posts to admins" do
          near_view = topic_view_near(p5, admin, show_deleted: true)
          expect(near_view.posts).to eq([p1, p2, p3, p4, p5, p6, p7])
          expect(near_view.contains_gaps?).to eq(false)
        end
      end
    end
  end

  describe "page_title" do
    fab!(:tag1) { Fabricate(:tag, staff_topic_count: 0, public_topic_count: 0) }
    fab!(:tag2) { Fabricate(:tag, staff_topic_count: 2, public_topic_count: 2) }
    fab!(:op_post) { Fabricate(:post, topic: topic) }
    fab!(:post1) { Fabricate(:post, topic: topic) }
    fab!(:whisper) { Fabricate(:post, topic: topic, post_type: Post.types[:whisper]) }

    subject { TopicView.new(topic.id, evil_trout).page_title }

    context "when a post number is specified" do
      context "with admins" do
        it "see post number and username for all posts" do
          title = TopicView.new(topic.id, admin, post_number: 0).page_title
          expect(title).to eq(topic.title)
          title = TopicView.new(topic.id, admin, post_number: 1).page_title
          expect(title).to eq(topic.title)

          title = TopicView.new(topic.id, admin, post_number: 2).page_title
          expect(title).to eq("#{topic.title} - #2 by #{post1.user.username}")
          title = TopicView.new(topic.id, admin, post_number: 3).page_title
          expect(title).to eq("#{topic.title} - #3 by #{whisper.user.username}")
        end
      end

      context "with regular users" do
        it "see post number and username for regular posts" do
          title = TopicView.new(topic.id, evil_trout, post_number: 0).page_title
          expect(title).to eq(topic.title)
          title = TopicView.new(topic.id, evil_trout, post_number: 1).page_title
          expect(title).to eq(topic.title)

          title = TopicView.new(topic.id, evil_trout, post_number: 2).page_title
          expect(title).to eq("#{topic.title} - #2 by #{post1.user.username}")
        end

        it "see only post number for whisper posts" do
          title = TopicView.new(topic.id, evil_trout, post_number: 3).page_title
          expect(title).to eq("#{topic.title} - #3")
          post2 = Fabricate(:post, topic: topic)
          topic.reload
          title = TopicView.new(topic.id, evil_trout, post_number: 3).page_title
          expect(title).to eq("#{topic.title} - #3")
          title = TopicView.new(topic.id, evil_trout, post_number: 4).page_title
          expect(title).to eq("#{topic.title} - #4 by #{post2.user.username}")
        end
      end
    end

    context "when a page number is specified" do
      it "does not include the page number for first page" do
        title = TopicView.new(topic.id, admin, page: 1).page_title
        expect(title).to eq("#{topic.title}")
      end

      it "includes page number for subsequent pages" do
        title = TopicView.new(topic.id, admin, page: 2).page_title
        expect(title).to eq("#{topic.title} - #{I18n.t("page_num", num: 2)}")
      end
    end

    context "with uncategorized topic" do
      context "when topic_page_title_includes_category is false" do
        before { SiteSetting.topic_page_title_includes_category = false }
        it { is_expected.to eq(topic.title) }
      end

      context "when topic_page_title_includes_category is true" do
        before { SiteSetting.topic_page_title_includes_category = true }
        it { is_expected.to eq(topic.title) }

        context "with tagged topic" do
          before { topic.tags << [tag1, tag2] }

          context "with tagging enabled" do
            before { SiteSetting.tagging_enabled = true }

            it { is_expected.to start_with(topic.title) }
            it { is_expected.not_to include(tag1.name) }
            it { is_expected.to end_with(tag2.name) } # tag2 has higher topic count
          end

          context "with tagging disabled" do
            before { SiteSetting.tagging_enabled = false }

            it { is_expected.to start_with(topic.title) }
            it { is_expected.not_to include(tag1.name) }
            it { is_expected.not_to include(tag2.name) }
          end

          context "with restricted tags" do
            let(:tag_group) { Fabricate.build(:tag_group) }
            let(:tag_group_permission) do
              Fabricate.build(:tag_group_permission, tag_group: tag_group)
            end

            before do
              SiteSetting.tagging_enabled = true
              # avoid triggering a `before_create` callback in `TagGroup` which
              # messes with permissions
              tag_group.tag_group_permissions << tag_group_permission
              tag_group.save!
              tag_group_permission.tag_group.tags << tag2
            end

            it { is_expected.not_to include(tag2.name) }
            it { is_expected.to include(tag1.name) }
          end
        end
      end
    end

    context "with categorized topic" do
      let(:category) { Fabricate(:category) }

      before { topic.update(category_id: category.id) }

      context "when topic_page_title_includes_category is false" do
        before { SiteSetting.topic_page_title_includes_category = false }
        it { is_expected.to eq(topic.title) }
      end

      context "when topic_page_title_includes_category is true" do
        before { SiteSetting.topic_page_title_includes_category = true }
        it { is_expected.to start_with(topic.title) }
        it { is_expected.to end_with(category.name) }

        context "with tagged topic" do
          before do
            SiteSetting.tagging_enabled = true
            topic.tags << [tag1, tag2]
          end

          it { is_expected.to start_with(topic.title) }
          it { is_expected.to end_with(category.name) }
          it { is_expected.not_to include(tag1.name) }
          it { is_expected.not_to include(tag2.name) }
        end
      end
    end
  end

  describe "#filtered_post_stream" do
    let!(:post) { Fabricate(:post, topic: topic, user: first_poster, created_at: 18.hours.ago) }
    let!(:post2) { Fabricate(:post, topic: topic, user: evil_trout, created_at: 6.hours.ago) }
    let!(:post3) { Fabricate(:post, topic: topic, user: first_poster) }

    it "should return the right columns" do
      expect(topic_view.filtered_post_stream).to eq([[post.id, 1], [post2.id, 0], [post3.id, 0]])
    end

    describe "for mega topics" do
      it "should return the right columns" do
        stub_const(TopicView, "MEGA_TOPIC_POSTS_COUNT", 2) do
          expect(topic_view.filtered_post_stream).to eq([post.id, post2.id, post3.id])
        end
      end
    end
  end

  describe "#filtered_post_id" do
    it "should return the right id" do
      post = Fabricate(:post, topic: topic)

      expect(topic_view.filtered_post_id(nil)).to eq(nil)
      expect(topic_view.filtered_post_id(post.post_number)).to eq(post.id)
    end
  end

  describe "#last_post_id" do
    let!(:p3) { Fabricate(:post, topic: topic) }
    let!(:p2) { Fabricate(:post, topic: topic) }
    let!(:p1) { Fabricate(:post, topic: topic) }

    before { [p1, p2, p3].each_with_index { |post, index| post.update!(sort_order: index + 1) } }

    it "should return the right id" do
      expect(topic_view.last_post_id).to eq(p3.id)
    end
  end

  describe "#read_time" do
    let!(:post) { Fabricate(:post, topic: topic) }

    before do
      PostCreator.create!(
        Discourse.system_user,
        topic_id: topic.id,
        raw: "![image|100x100](upload://upload.png)",
      )
      topic_view.topic.reload
    end

    it "should return the right read time" do
      SiteSetting.read_time_word_count = 500
      expect(topic_view.read_time).to eq(1)

      SiteSetting.read_time_word_count = 0
      expect(topic_view.read_time).to eq(nil)
    end
  end

  describe "#mentioned_users" do
    it "works with capitalized usernames" do
      user = Fabricate(:user, username: "JoJo")
      post_1 = Fabricate(:post, topic: topic, raw: "Hey @#{user.username}")

      view = TopicView.new(topic.id, user).mentioned_users

      expect(view[post_1.id]).to eq([user])
    end
  end

  describe "#image_url" do
    fab!(:op_upload, :image_upload)
    fab!(:post3_upload, :image_upload)

    fab!(:post1) { Fabricate(:post, topic: topic) }
    fab!(:post2) { Fabricate(:post, topic: topic) }
    fab!(:post3) do
      Fabricate(:post, topic: topic)
        .tap { |p| p.update_column(:image_upload_id, post3_upload.id) }
        .reload
    end

    def topic_view_for_post(post_number)
      TopicView.new(topic.id, evil_trout, post_number: post_number)
    end

    context "when op has an image" do
      before do
        topic.update_column(:image_upload_id, op_upload.id)
        post1.update_column(:image_upload_id, op_upload.id)
      end

      it "uses the topic image for op and posts image when they have one" do
        expect(topic_view_for_post(1).image_url).to end_with(op_upload.url)
        expect(topic_view_for_post(2).image_url).to eq(nil)
        expect(topic_view_for_post(3).image_url).to end_with(post3_upload.url)
      end
    end

    context "when op has no image" do
      it "returns nil when posts have no image" do
        expect(topic_view_for_post(1).image_url).to eq(nil)
        expect(topic_view_for_post(2).image_url).to eq(nil)
        expect(topic_view_for_post(3).image_url).to end_with(post3_upload.url)
      end
    end
  end

  describe "#show_read_indicator?" do
    let(:topic) { Fabricate(:topic) }
    let(:pm_topic) { Fabricate(:private_message_topic) }

    it "shows read indicator for private messages" do
      group = Fabricate(:group, users: [admin], publish_read_state: true)
      pm_topic.topic_allowed_groups = [Fabricate.build(:topic_allowed_group, group: group)]

      topic_view = TopicView.new(pm_topic.id, admin)
      expect(topic_view.show_read_indicator?).to be_truthy
    end

    it "does not show read indicator if groups do not have read indicator enabled" do
      topic_view = TopicView.new(pm_topic.id, admin)
      expect(topic_view.show_read_indicator?).to be_falsey
    end

    it "does not show read indicator for topics with allowed groups" do
      group = Fabricate(:group, users: [admin], publish_read_state: true)
      topic.topic_allowed_groups = [Fabricate.build(:topic_allowed_group, group: group)]

      topic_view = TopicView.new(topic.id, admin)
      expect(topic_view.show_read_indicator?).to be_falsey
    end
  end

  describe "#reviewable_counts" do
    it "exclude posts queued because the category needs approval" do
      category =
        Fabricate.create(
          :category,
          user: admin,
          category_setting_attributes: {
            require_topic_approval: true,
          },
        )
      manager =
        NewPostManager.new(
          user,
          raw: "to the handler I say enqueue me!",
          title: "this is the title of the queued post",
          category: category.id,
        )
      result = manager.perform
      reviewable = result.reviewable
      reviewable.perform(admin, :approve_post)

      topic_view = TopicView.new(reviewable.topic, admin)

      expect(topic_view.reviewable_counts).to be_empty
    end

    it "include posts queued for other reasons" do
      Fabricate(:watched_word, word: "darn", action: WatchedWord.actions[:require_approval])
      manager =
        NewPostManager.new(
          user,
          raw: "this is darn new post content",
          title: "this is the title of the queued post",
        )
      result = manager.perform
      reviewable = result.reviewable
      reviewable.perform(admin, :approve_post)

      topic_view = TopicView.new(reviewable.topic, admin)

      expect(topic_view.reviewable_counts.keys).to contain_exactly(reviewable.target_id)
    end
  end

  describe ".apply_custom_default_scope" do
    fab!(:post) { Fabricate(:post, topic: topic, created_at: 2.hours.ago) }
    fab!(:post_2) { Fabricate(:post, topic: topic, created_at: 1.hour.ago) }

    after { TopicView.reset_custom_default_scopes }

    it "allows a custom default scope to be configured" do
      topic_view = TopicView.new(topic, admin)

      expect(topic_view.filtered_post_ids).to eq([post.id, post_2.id])

      TopicView.apply_custom_default_scope do |scope, _|
        scope.unscope(:order).order("posts.created_at DESC")
      end

      topic_view = TopicView.new(topic, admin)

      expect(topic_view.filtered_post_ids).to eq([post_2.id, post.id])
    end
  end

  describe "#queued_posts_enabled?" do
    subject(:topic_view) { described_class.new(topic, user) }

    let(:topic) { Fabricate(:topic) }
    let(:user) { Fabricate(:user) }
    let(:category) { topic.category }

    before { NewPostManager.stubs(:queue_enabled?).returns(queue_enabled) }

    context "when queue is enabled globally" do
      let(:queue_enabled) { true }

      it { expect(topic_view.queued_posts_enabled?).to be(true) }
    end

    context "when queue is not enabled globally" do
      let(:queue_enabled) { false }

      context "when category is moderated" do
        before do
          category.require_reply_approval = true
          category.save!
        end

        it { expect(topic_view.queued_posts_enabled?).to be(true) }
      end

      context "when category is not moderated" do
        it { expect(topic_view.queued_posts_enabled?).to be(false) }
      end
    end
  end

  describe "plugin modifiers" do
    let(:plugin) { Plugin::Instance.new }

    context "with topic_view_link_counts modifier registered" do
      let(:modifier) do
        Proc.new do |link_counts|
          link_counts["hijacked hehe"] = true
          link_counts
        end
      end

      it "allows modifications to link_counts" do
        expect(TopicView.new(topic).link_counts).to eq({})

        plugin.register_modifier(:topic_view_link_counts, &modifier)

        expect(TopicView.new(topic).link_counts).to eq({ "hijacked hehe" => true })
      ensure
        DiscoursePluginRegistry.unregister_modifier(plugin, :topic_view_link_counts, &modifier)
      end
    end

    context "with topic_view_suggested_topics_options modifier" do
      let!(:topic1) { Fabricate(:topic) }
      let!(:topic2) { Fabricate(:topic) }
      let(:modifier) do
        Proc.new do |suggested_options, inner_topic_view|
          suggested_options.merge(include_random: false)
        end
      end

      it "allows modifications to suggested topics (disabling of random suggested)" do
        expect(TopicView.new(topic1).suggested_topics.topics.count).to be > 0

        plugin.register_modifier(:topic_view_suggested_topics_options, &modifier)

        expect(TopicView.new(topic1).suggested_topics.topics.count).to eq(0)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :topic_view_suggested_topics_options,
          &modifier
        )
      end
    end
  end
end
