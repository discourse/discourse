# frozen_string_literal: true

RSpec.describe DirectoryItem do
  describe "#period_types" do
    context "when verifying enum sequence" do
      it "'all' should be at 1st position" do
        expect(described_class.period_types[:all]).to eq(1)
      end

      it "'quarterly' should be at 6th position" do
        expect(described_class.period_types[:quarterly]).to eq(6)
      end
    end
  end

  describe "eligible users" do
    fab!(:post) { create_post }

    before { DirectoryItem.refresh_period!(:daily) }

    it "removes inactive users correctly" do
      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)

      post.user.update_columns(active: false)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(0)

      post.user.update_columns(active: true)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)
    end

    it "removes bot users correctly" do
      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)

      post.user.update_columns(id: User.minimum(:id) - 100)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(0)
    end

    it "removes silenced users correctly" do
      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)

      post.user.update_columns(silenced_till: 1.year.from_now)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(0)
    end
  end

  describe ".refresh!" do
    before do
      freeze_time_safe
      UserActionManager.enable
    end

    it "creates the record for the user and handles likes given, likes received, post count, and topic count" do
      post = create_post
      _post2 = create_post(topic_id: post.topic_id, user: post.user)

      user2 = Fabricate(:user)

      PostActionCreator.like(user2, post)

      DirectoryItem.refresh!

      item1 =
        DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: post.user_id)
      item2 =
        DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: user2.id)

      expect(item1.topic_count).to eq(1)
      expect(item1.likes_received).to eq(1)
      expect(item1.post_count).to eq(1)

      expect(item2.likes_given).to eq(1)

      post.topic.trash!

      DirectoryItem.refresh!

      item1 =
        DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: post.user_id)
      item2 =
        DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: user2.id)

      expect(item1.likes_given).to eq(0)
      expect(item1.likes_received).to eq(0)
      expect(item1.post_count).to eq(0)
      expect(item1.topic_count).to eq(0)
    end

    it "handles users with no activity" do
      post = nil

      freeze_time(2.years.ago)

      post = create_post
      DirectoryItem.refresh!

      freeze_time(2.years.from_now)

      DirectoryItem.refresh!
      %i[yearly monthly weekly daily quarterly].each do |period|
        directory_item =
          DirectoryItem
            .where(period_type: DirectoryItem.period_types[period])
            .where(user_id: post.user.id)
            .first
        expect(directory_item.topic_count).to eq(0)
        expect(directory_item.post_count).to eq(0)
      end

      directory_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:all])
          .where(user_id: post.user.id)
          .first
      expect(directory_item.topic_count).to eq(1)
    end

    it "creates directory item with correct activity count per period_type" do
      user = Fabricate(:user)
      UserVisit.create(
        user_id: user.id,
        visited_at: 1.minute.ago,
        posts_read: 1,
        mobile: false,
        time_read: 1,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 2.days.ago,
        posts_read: 1,
        mobile: false,
        time_read: 1,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 1.week.ago,
        posts_read: 1,
        mobile: false,
        time_read: 1,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 1.month.ago,
        posts_read: 1,
        mobile: false,
        time_read: 1,
      )

      DirectoryItem.refresh!

      daily_directory_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:daily])
          .where(user_id: user.id)
          .first

      expect(daily_directory_item.days_visited).to eq(1)

      weekly_directory_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:weekly])
          .where(user_id: user.id)
          .first

      expect(weekly_directory_item.days_visited).to eq(2)

      monthly_directory_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:monthly])
          .where(user_id: user.id)
          .first

      expect(monthly_directory_item.days_visited).to eq(3)
    end

    context "when must_approve_users is true" do
      before { SiteSetting.must_approve_users = true }

      it "doesn't include user who hasn't been approved" do
        user = Fabricate(:user, approved: false)
        DirectoryItem.refresh!
        expect(DirectoryItem.where(user_id: user.id).count).to eq(0)
      end
    end

    context "with anonymous posting" do
      fab!(:user)
      fab!(:group) { Fabricate(:group, users: [user]) }

      before do
        SiteSetting.allow_anonymous_mode = true
        SiteSetting.anonymous_posting_allowed_groups = group.id.to_s
      end

      it "doesn't create records for anonymous users" do
        anon = AnonymousShadowCreator.get(user)
        DirectoryItem.refresh!
        expect(DirectoryItem.where(user_id: anon.id)).to be_blank
        expect(DirectoryItem.where(user_id: user.id)).to be_present
      end
    end
  end

  describe "topics_entered, days_visited, and posts_read counts" do
    fab!(:user)

    before do
      freeze_time_safe
      UserActionManager.enable
    end

    it "correctly counts topics_entered, days_visited, and posts_read per period_type" do
      # Create topic views at different times
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (1, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.minute.ago.to_date,
      )
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (2, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 2.days.ago.to_date,
      )
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (3, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.week.ago.to_date,
      )
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (4, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.month.ago.to_date,
      )

      # Create user visits at different times with posts_read
      UserVisit.create!(
        user_id: user.id,
        visited_at: 1.minute.ago.to_date,
        posts_read: 5,
        mobile: false,
        time_read: 100,
      )
      UserVisit.create!(
        user_id: user.id,
        visited_at: 2.days.ago.to_date,
        posts_read: 3,
        mobile: false,
        time_read: 200,
      )
      UserVisit.create!(
        user_id: user.id,
        visited_at: 1.week.ago.to_date,
        posts_read: 7,
        mobile: false,
        time_read: 150,
      )
      UserVisit.create!(
        user_id: user.id,
        visited_at: 1.month.ago.to_date,
        posts_read: 2,
        mobile: false,
        time_read: 50,
      )

      DirectoryItem.refresh!

      # Daily period - only items from the last day
      daily_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:daily])
          .where(user_id: user.id)
          .first
      expect(daily_item.topics_entered).to eq(1)
      expect(daily_item.days_visited).to eq(1)
      expect(daily_item.posts_read).to eq(5)

      # Weekly period - items from the last week
      weekly_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:weekly])
          .where(user_id: user.id)
          .first
      expect(weekly_item.topics_entered).to eq(2)
      expect(weekly_item.days_visited).to eq(2)
      expect(weekly_item.posts_read).to eq(8)

      # Monthly period - items from the last month
      monthly_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:monthly])
          .where(user_id: user.id)
          .first
      expect(monthly_item.topics_entered).to eq(3)
      expect(monthly_item.days_visited).to eq(3)
      expect(monthly_item.posts_read).to eq(15)

      # All period - all items
      all_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:all])
          .where(user_id: user.id)
          .first
      expect(all_item.topics_entered).to eq(4)
      expect(all_item.days_visited).to eq(4)
      expect(all_item.posts_read).to eq(17)
    end

    it "handles zero values correctly" do
      DirectoryItem.refresh!

      daily_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:daily])
          .where(user_id: user.id)
          .first

      expect(daily_item.topics_entered).to eq(0)
      expect(daily_item.days_visited).to eq(0)
      expect(daily_item.posts_read).to eq(0)
    end

    it "only counts unique topic views per user" do
      # Insert the same topic view multiple times (shouldn't happen, but test the query)
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (1, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.minute.ago.to_date,
      )
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (2, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.minute.ago.to_date,
      )

      DirectoryItem.refresh!

      daily_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:daily])
          .where(user_id: user.id)
          .first

      expect(daily_item.topics_entered).to eq(2) # Two different topics
    end

    it "updates existing directory items when values change" do
      # Initial data
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (1, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.minute.ago.to_date,
      )
      UserVisit.create!(
        user_id: user.id,
        visited_at: 1.minute.ago.to_date,
        posts_read: 5,
        mobile: false,
        time_read: 100,
      )

      DirectoryItem.refresh!

      daily_item =
        DirectoryItem
          .where(period_type: DirectoryItem.period_types[:daily])
          .where(user_id: user.id)
          .first

      expect(daily_item.topics_entered).to eq(1)
      expect(daily_item.days_visited).to eq(1)
      expect(daily_item.posts_read).to eq(5)

      # Add more data
      DB.exec(
        "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (2, :user_id, :viewed_at, '127.0.0.1')",
        user_id: user.id,
        viewed_at: 1.minute.ago.to_date,
      )
      UserVisit.find_by(user_id: user.id, visited_at: 1.minute.ago.to_date).update!(posts_read: 10)

      DirectoryItem.refresh_period!(:daily)

      daily_item.reload
      expect(daily_item.topics_entered).to eq(2)
      expect(daily_item.days_visited).to eq(1)
      expect(daily_item.posts_read).to eq(10)
    end
  end
end
