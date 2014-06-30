require 'spec_helper'
require 'topic_view'

describe TopicQuery do

  let!(:user) { Fabricate(:coding_horror) }
  let(:creator) { Fabricate(:user) }
  let(:topic_query) { TopicQuery.new(user) }

  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:admin) }

  context 'secure category' do
    it "filters categories out correctly" do
      category = Fabricate(:category)
      group = Fabricate(:group)
      category.set_permissions(group => :full)
      category.save

      topic = Fabricate(:topic, category: category)
      topic = Fabricate(:topic, visible: false)

      TopicQuery.new(nil).list_latest.topics.count.should == 0
      TopicQuery.new(user).list_latest.topics.count.should == 0

      Topic.top_viewed(10).count.should == 0
      Topic.recent(10).count.should == 0

      # mods can see hidden topics
      TopicQuery.new(moderator).list_latest.topics.count.should == 1
      # admins can see all the topics
      TopicQuery.new(admin).list_latest.topics.count.should == 3

      group.add(user)
      group.save

      TopicQuery.new(user).list_latest.topics.count.should == 2

    end

  end

  context 'category filter' do
    let(:category) { Fabricate(:category) }

    let(:diff_category) { Fabricate(:category) }

    it "returns topics in the category when we filter to it" do
      TopicQuery.new(moderator).list_latest.topics.size.should == 0

      # Filter by slug
      TopicQuery.new(moderator, category: category.slug).list_latest.topics.size.should == 1
      TopicQuery.new(moderator, category: "#{category.id}-category").list_latest.topics.size.should == 1
      TopicQuery.new(moderator, category: diff_category.slug).list_latest.topics.size.should == 1

      # Defaults to no category filter when slug does not exist
      TopicQuery.new(moderator, category: 'made up slug').list_latest.topics.size.should == 2
    end

    context 'subcategories' do
      let!(:subcategory) { Fabricate(:category, parent_category_id: category.id)}

      it "works with subcategories" do
        TopicQuery.new(moderator, category: category.id).list_latest.topics.size.should == 1
        TopicQuery.new(moderator, category: subcategory.id).list_latest.topics.size.should == 1
        TopicQuery.new(moderator, category: category.id, no_subcategories: true).list_latest.topics.size.should == 1
      end

    end


  end

  context 'muted categories' do
    it 'is removed from new and latest lists' do
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      CategoryUser.create!(user_id: user.id,
                           category_id: category.id,
                           notification_level: CategoryUser.notification_levels[:muted])
      topic_query.list_new.topics.map(&:id).should_not include(topic.id)
      topic_query.list_latest.topics.map(&:id).should_not include(topic.id)
    end
  end

  context 'a bunch of topics' do
    let!(:regular_topic) do
      Fabricate(:topic, title: 'this is a regular topic',
                        user: creator,
                        views: 100,
                        like_count: 66,
                        posts_count: 3,
                        participant_count: 11,
                        bumped_at: 15.minutes.ago)
    end
    let!(:pinned_topic) do
      Fabricate(:topic, title: 'this is a pinned topic',
                        user: creator,
                        views: 10,
                        like_count: 100,
                        posts_count: 5,
                        participant_count: 12,
                        pinned_at: 10.minutes.ago,
                        pinned_globally: true,
                        bumped_at: 10.minutes.ago)
    end
    let!(:archived_topic) do
      Fabricate(:topic, title: 'this is an archived topic',
                        user: creator,
                        views: 50,
                        like_count: 30,
                        posts_count: 4,
                        archived: true,
                        participant_count: 1,
                        bumped_at: 6.minutes.ago)
    end
    let!(:invisible_topic) do
      Fabricate(:topic, title: 'this is an invisible topic',
                        user: creator,
                        views: 1,
                        like_count: 5,
                        posts_count: 2,
                        visible: false,
                        participant_count: 3,
                        bumped_at: 5.minutes.ago)
    end
    let!(:closed_topic) do
      Fabricate(:topic, title: 'this is a closed topic',
                        user: creator,
                        views: 2,
                        like_count: 1,
                        posts_count: 1,
                        closed: true,
                        participant_count: 2,
                        bumped_at: 1.minute.ago)
    end

    let(:topics) { topic_query.list_latest.topics }

    context 'list_latest' do
      it "returns the topics in the correct order" do
        topics.map(&:id).should == [pinned_topic, closed_topic, archived_topic, regular_topic].map(&:id)

        # includes the invisible topic if you're a moderator
        TopicQuery.new(moderator).list_latest.topics.include?(invisible_topic).should be_true

        # includes the invisible topic if you're an admin" do
        TopicQuery.new(admin).list_latest.topics.include?(invisible_topic).should be_true
      end

      context 'sort_order' do

        def ids_in_order(order, descending=true)
          TopicQuery.new(admin, order: order, ascending: descending ? 'false' : 'true').list_latest.topics.map(&:id)
        end

        it "returns the topics in correct order" do
          # returns the topics in likes order if requested
          ids_in_order('posts').should == [pinned_topic, archived_topic, regular_topic, invisible_topic, closed_topic].map(&:id)

          # returns the topics in reverse likes order if requested
          ids_in_order('posts', false).should == [closed_topic, invisible_topic, regular_topic, archived_topic, pinned_topic].map(&:id)

          # returns the topics in likes order if requested
          ids_in_order('likes').should == [pinned_topic, regular_topic, archived_topic, invisible_topic, closed_topic].map(&:id)

          # returns the topics in reverse likes order if requested
          ids_in_order('likes', false).should == [closed_topic, invisible_topic, archived_topic, regular_topic, pinned_topic].map(&:id)

          # returns the topics in views order if requested
          ids_in_order('views').should == [regular_topic, archived_topic, pinned_topic, closed_topic, invisible_topic].map(&:id)

          # returns the topics in reverse views order if requested" do
          ids_in_order('views', false).should == [invisible_topic, closed_topic, pinned_topic, archived_topic, regular_topic].map(&:id)

          # returns the topics in posters order if requested" do
          ids_in_order('posters').should == [pinned_topic, regular_topic, invisible_topic, closed_topic, archived_topic].map(&:id)

          # returns the topics in reverse posters order if requested" do
          ids_in_order('posters', false).should == [archived_topic, closed_topic, invisible_topic, regular_topic, pinned_topic].map(&:id)
        end

      end

    end


    context 'after clearring a pinned topic' do
      before do
        pinned_topic.clear_pin_for(user)
      end

      it "no longer shows the pinned topic at the top" do
        topics.should == [closed_topic, archived_topic, pinned_topic, regular_topic]
      end
    end

  end

  context 'categorized' do
    let(:category) { Fabricate(:category) }
    let(:topic_category) { category.topic }
    let!(:topic_no_cat) { Fabricate(:topic) }
    let!(:topic_in_cat) { Fabricate(:topic, category: category) }

    it "returns the topic with a category when filtering by category" do
      topic_query.list_category(category).topics.should == [topic_category, topic_in_cat]
    end

    it "returns only the topic category when filtering by another category" do
      another_category = Fabricate(:category, name: 'new cat')
      topic_query.list_category(another_category).topics.should == [another_category.topic]
    end

    describe '#list_new_in_category' do
      it 'returns the topic category and the categorized topic' do
        topic_query.list_new_in_category(category).topics.should == [topic_in_cat, topic_category]
      end
    end
  end

  context 'unread / read topics' do

    context 'with no data' do
      it "has no unread topics" do
        topic_query.list_unread.topics.should be_blank
      end
    end

    context 'with read data' do
      let!(:partially_read) { Fabricate(:post, user: creator).topic }
      let!(:fully_read) { Fabricate(:post, user: creator).topic }

      before do
        TopicUser.update_last_read(user, partially_read.id, 0, 0)
        TopicUser.update_last_read(user, fully_read.id, 1, 0)
      end

      context 'list_unread' do
        it 'contains no topics' do
          topic_query.list_unread.topics.should == []
        end
      end

      context 'user with auto_track_topics list_unread' do
        before do
          user.auto_track_topics_after_msecs = 0
          user.save
        end

        it 'only contains the partially read topic' do
          topic_query.list_unread.topics.should == [partially_read]
        end
      end

      context 'list_read' do
        it 'contain both topics ' do
          topic_query.list_read.topics.should =~ [fully_read, partially_read]
        end
      end
    end

  end

  context 'list_starred' do

    let(:topic) { Fabricate(:topic) }

    it "returns no results when the user hasn't starred any topics" do
      topic_query.list_starred.topics.should be_blank
    end

    context 'with a starred topic' do

      before do
        topic.toggle_star(user, true)
      end

      it "returns the topic after it has been starred" do
        topic_query.list_starred.topics.should == [topic]
      end
    end

  end

  context 'list_new' do

    context 'without a new topic' do
      it "has no new topics" do
        topic_query.list_new.topics.should be_blank
      end
    end

    context 'with a new topic' do
      let!(:new_topic) { Fabricate(:topic, user: creator, bumped_at: 10.minutes.ago) }
      let(:topics) { topic_query.list_new.topics }


      it "contains the new topic" do
        topics.should == [new_topic]
      end

      it "contains no new topics for a user that has missed the window" do
        user.new_topic_duration_minutes = 5
        user.save
        new_topic.created_at = 10.minutes.ago
        new_topic.save
        topics.should == []
      end

      context "muted topics" do
        before do
          new_topic.notify_muted!(user)
        end

        it "returns an empty set" do
          topics.should be_blank
        end

        context 'un-muted' do
          before do
            new_topic.notify_tracking!(user)
          end

          it "returns the topic again" do
            topics.should == [new_topic]
          end
        end
      end
    end

  end

  context 'list_posted' do
    let(:topics) { topic_query.list_posted.topics }

    it "returns blank when there are no posted topics" do
      topics.should be_blank
    end

    context 'created topics' do
      let!(:created_topic) { create_post(user: user).topic }

      it "includes the created topic" do
        topics.include?(created_topic).should be_true
      end
    end

    context "topic you've posted in" do
      let(:other_users_topic) { create_post(user: creator).topic }
      let!(:your_post) { create_post(user: user, topic: other_users_topic )}

      it "includes the posted topic" do
        topics.include?(other_users_topic).should be_true
      end
    end

    context "topic you haven't posted in" do
      let(:other_users_topic) { create_post(user: creator).topic }

      it "does not include the topic" do
        topics.should be_blank
      end

      context "but interacted with" do
        it "is not included if starred" do
          other_users_topic.toggle_star(user, true)

          topics.should be_blank
        end

        it "is not included if read" do
          TopicUser.update_last_read(user, other_users_topic.id, 0, 0)

          topics.should be_blank
        end

        it "is not included if muted" do
          other_users_topic.notify_muted!(user)

          topics.should be_blank
        end

        it "is not included if tracking" do
          other_users_topic.notify_tracking!(user)

          topics.should be_blank
        end
      end
    end
  end

  context 'suggested_for' do

    context 'when anonymous' do
      let(:topic) { Fabricate(:topic) }
      let!(:new_topic) { Fabricate(:post, user: creator).topic }

      it "should return the new topic" do
        TopicQuery.new.list_suggested_for(topic).topics.should == [new_topic]
      end
    end

    context "anonymously browsing with invisible, closed and archived" do
      let!(:topic) { Fabricate(:topic) }
      let!(:regular_topic) { Fabricate(:post, user: creator).topic }
      let!(:closed_topic) { Fabricate(:topic, user: creator, closed: true) }
      let!(:archived_topic) { Fabricate(:topic, user: creator, archived: true) }
      let!(:invisible_topic) { Fabricate(:topic, user: creator, visible: false) }

      it "should omit the closed/archived/invisbiel topics from suggested" do
        TopicQuery.new.list_suggested_for(topic).topics.should == [regular_topic]
      end
    end

    context 'when logged in' do

      let(:topic) { Fabricate(:topic) }
      let(:suggested_topics) { topic_query.list_suggested_for(topic).topics.map{|t| t.id} }

      it "should return empty results when there is nothing to find" do
        suggested_topics.should be_blank
      end

      context 'with some existing topics' do
        let!(:partially_read) { Fabricate(:post, user: creator).topic }
        let!(:new_topic) { Fabricate(:post, user: creator).topic }
        let!(:fully_read) { Fabricate(:post, user: creator).topic }
        let!(:closed_topic) { Fabricate(:topic, user: creator, closed: true) }
        let!(:archived_topic) { Fabricate(:topic, user: creator, archived: true) }
        let!(:invisible_topic) { Fabricate(:topic, user: creator, visible: false) }
        let!(:fully_read_closed) { Fabricate(:post, user: creator).topic }
        let!(:fully_read_archived) { Fabricate(:post, user: creator).topic }

        before do
          user.auto_track_topics_after_msecs = 0
          user.save
          TopicUser.update_last_read(user, partially_read.id, 0, 0)
          TopicUser.update_last_read(user, fully_read.id, 1, 0)
          TopicUser.update_last_read(user, fully_read_closed.id, 1, 0)
          TopicUser.update_last_read(user, fully_read_archived.id, 1, 0)
          fully_read_closed.closed = true
          fully_read_closed.save
          fully_read_archived.archived = true
          fully_read_archived.save
        end

        it "won't return new or fully read if there are enough partially read topics" do
          SiteSetting.stubs(:suggested_topics).returns(1)
          suggested_topics.should == [partially_read.id]
        end

        it "won't return fully read if there are enough partially read topics and new topics" do
          SiteSetting.stubs(:suggested_topics).returns(4)
          suggested_topics[0].should == partially_read.id
          suggested_topics[1,3].should include(new_topic.id)
          suggested_topics[1,3].should include(closed_topic.id)
          suggested_topics[1,3].should include(archived_topic.id)
        end

        it "returns unread, then new, then random" do
          SiteSetting.stubs(:suggested_topics).returns(7)
          suggested_topics[0].should == partially_read.id
          suggested_topics[1,3].should include(new_topic.id)
          suggested_topics[1,3].should include(closed_topic.id)
          suggested_topics[1,3].should include(archived_topic.id)
          suggested_topics[4].should == fully_read.id
          # random doesn't include closed and archived
        end

      end
    end

  end

end
