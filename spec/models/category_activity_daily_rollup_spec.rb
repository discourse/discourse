# frozen_string_literal: true

RSpec.describe CategoryActivityDailyRollup do
  fab!(:category)

  before { freeze_time(Time.zone.local(2026, 4, 28, 12)) }

  describe ".aggregate" do
    it "stores one row per category per day with topic, post and page view counts" do
      topic = Fabricate(:topic, category: category, created_at: 3.days.ago)
      Fabricate(:post, topic: topic, created_at: 3.days.ago)
      Fabricate(:post, topic: topic, created_at: 2.days.ago)
      TopicViewStat.create!(
        topic: topic,
        viewed_at: 3.days.ago.to_date,
        anonymous_views: 7,
        logged_in_views: 3,
      )

      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      rows = described_class.where(category_id: category.id).order(:date)
      expect(rows.map { |row| [row.date, row.topics, row.posts, row.page_views] }).to eq(
        [[3.days.ago.to_date, 1, 1, 10], [2.days.ago.to_date, 0, 1, 0]],
      )
    end

    it "records likely crawler pageviews from browser events separately" do
      topic = Fabricate(:topic, category: category, created_at: 3.days.ago)
      TopicViewStat.create!(
        topic: topic,
        viewed_at: 3.days.ago.to_date,
        anonymous_views: 7,
        logged_in_views: 3,
      )
      Fabricate(
        :browser_pageview_event,
        topic_id: topic.id,
        ip_address: "1.1.1.1",
        created_at: 3.days.ago,
        score: 90,
      )
      Fabricate(
        :browser_pageview_event,
        topic_id: topic.id,
        ip_address: "2.2.2.2",
        created_at: 3.days.ago,
        score: 90,
      )
      Fabricate(:browser_pageview_event, topic_id: topic.id, created_at: 3.days.ago, score: 10)

      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.find_by(category: category, date: 3.days.ago.to_date)).to(
        have_attributes(page_views: 10, likely_crawler_page_views: 2),
      )
    end

    it "counts a crawler revisiting the same topic once a day, matching topic view stats" do
      topic = Fabricate(:topic, category: category, created_at: 3.days.ago)
      TopicViewStat.create!(
        topic: topic,
        viewed_at: 3.days.ago.to_date,
        anonymous_views: 5,
        logged_in_views: 0,
      )
      20.times do
        Fabricate(
          :browser_pageview_event,
          topic_id: topic.id,
          ip_address: "1.1.1.1",
          created_at: 3.days.ago,
          score: 90,
        )
      end

      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.find_by(category: category, date: 3.days.ago.to_date)).to(
        have_attributes(page_views: 5, likely_crawler_page_views: 1),
      )
    end

    it "does not create a row for a day whose only signal is crawler pageviews" do
      topic = Fabricate(:topic, category: category, created_at: 10.days.ago)
      Fabricate(:browser_pageview_event, topic_id: topic.id, created_at: 3.days.ago, score: 90)

      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.where(date: 3.days.ago.to_date)).to be_empty
    end

    it "keeps crawler pageviews for dates whose source events have been pruned" do
      topic = Fabricate(:topic, category: category, created_at: 3.days.ago)
      TopicViewStat.create!(
        topic: topic,
        viewed_at: 3.days.ago.to_date,
        anonymous_views: 10,
        logged_in_views: 0,
      )
      Fabricate(:browser_pageview_event, topic_id: topic.id, created_at: 3.days.ago, score: 90)
      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      BrowserPageviewEvent.delete_all
      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.find_by(category: category, date: 3.days.ago.to_date)).to(
        have_attributes(page_views: 10, likely_crawler_page_views: 1),
      )
    end

    it "recomputes crawler pageviews downward while the source events remain" do
      topic = Fabricate(:topic, category: category, created_at: 3.days.ago)
      TopicViewStat.create!(
        topic: topic,
        viewed_at: 3.days.ago.to_date,
        anonymous_views: 10,
        logged_in_views: 0,
      )
      crawler_event =
        Fabricate(:browser_pageview_event, topic_id: topic.id, created_at: 3.days.ago, score: 90)
      Fabricate(:browser_pageview_event, topic_id: topic.id, created_at: 3.days.ago, score: 10)
      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      crawler_event.update!(score: 10)
      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.find_by(category: category, date: 3.days.ago.to_date)).to(
        have_attributes(page_views: 10, likely_crawler_page_views: 0),
      )
    end

    it "ignores deleted topics, deleted posts and private messages" do
      Fabricate(:topic, category: category, created_at: 1.day.ago, deleted_at: Time.zone.now)
      Fabricate(:private_message_topic, category: category, created_at: 1.day.ago)
      visible_topic = Fabricate(:topic, category: category, created_at: 1.day.ago)
      Fabricate(:post, topic: visible_topic, created_at: 1.day.ago, deleted_at: Time.zone.now)

      described_class.aggregate(start_date: 5.days.ago, end_date: Time.zone.today)

      expect(described_class.where(category_id: category.id).pluck(:topics, :posts)).to eq([[1, 0]])
    end

    it "covers windows longer than a single aggregation chunk" do
      Fabricate(:topic, category: category, created_at: 200.days.ago)
      Fabricate(:topic, category: category, created_at: 1.day.ago)

      described_class.aggregate(start_date: 300.days.ago, end_date: Time.zone.today)

      expect(described_class.pluck(:date)).to contain_exactly(
        200.days.ago.to_date,
        1.day.ago.to_date,
      )
    end

    it "serialises writers so overlapping windows cannot collide on the unique index" do
      Fabricate(:topic, category: category, created_at: 1.day.ago)
      held = false
      DistributedMutex.synchronize(described_class::AGGREGATE_LOCK_KEY) do
        Thread.new { described_class.aggregate(start_date: 2.days.ago, end_date: Time.zone.today) }
        sleep 0.1
        held = described_class.count.zero?
      end

      expect(held).to eq(true)
    end

    it "takes the lock once per chunk so a long rebuild cannot outlive its lease" do
      Fabricate(:topic, category: category, created_at: 200.days.ago)

      DistributedMutex
        .expects(:synchronize)
        .with(
          described_class::AGGREGATE_LOCK_KEY,
          validity: described_class::AGGREGATE_LOCK_VALIDITY,
        )
        .times(3)
        .yields

      described_class.aggregate(start_date: 269.days.ago, end_date: Time.zone.today)

      expect(described_class.exists?(date: 200.days.ago.to_date)).to eq(true)
    end

    it "keeps existing rows when a refresh fails" do
      existing = Fabricate(:category_activity_daily_rollup, category: category, topics: 3)
      described_class.stubs(:insert_all!).raises(ActiveRecord::StatementInvalid)
      Fabricate(:topic, category: category, created_at: Time.zone.now)

      expect do
        described_class.aggregate(start_date: Time.zone.today, end_date: Time.zone.today)
      end.to raise_error(ActiveRecord::StatementInvalid)

      expect(existing.reload.topics).to eq(3)
    end
  end

  describe ".earliest_activity_date" do
    it "returns the creation date of the oldest topic the rollup counts" do
      Fabricate(:topic, category: category, created_at: 10.days.ago)
      Fabricate(:topic, category: category, created_at: 2.days.ago)

      expect(described_class.earliest_activity_date).to eq(10.days.ago.to_date)
    end

    it "ignores topics excluded from the rollup so the job has nothing to aggregate" do
      Fabricate(:topic, category: category, created_at: 10.days.ago, deleted_at: Time.zone.now)
      Fabricate(:private_message_topic, created_at: 10.days.ago)

      expect(described_class.earliest_activity_date).to eq(nil)
    end
  end

  describe ".period_totals" do
    it "splits activity into the current and prior period" do
      Fabricate(
        :category_activity_daily_rollup,
        category: category,
        date: 10.days.ago,
        topics: 5,
        posts: 0,
        page_views: 0,
      )
      Fabricate(
        :category_activity_daily_rollup,
        category: category,
        date: 2.days.ago,
        topics: 2,
        posts: 3,
        page_views: 4,
      )

      row =
        described_class.period_totals(
          prev_start: 14.days.ago.to_date,
          current_start: 7.days.ago.to_date,
          current_end: Time.zone.today,
        ).first

      expect(row.topics_current).to eq(2)
      expect(row.posts_current).to eq(3)
      expect(row.page_views_current).to eq(4)
      expect(row.topics_prior).to eq(5)
      expect(row.topics_current).to be_a(Integer)
    end

    it "subtracts likely crawler pageviews once crawler detection is enabled" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(
        :category_activity_daily_rollup,
        category: category,
        date: 2.days.ago,
        topics: 0,
        posts: 0,
        page_views: 10,
        likely_crawler_page_views: 4,
      )

      row =
        described_class.period_totals(
          prev_start: 14.days.ago.to_date,
          current_start: 7.days.ago.to_date,
          current_end: Time.zone.today,
        ).first

      expect(row.page_views_current).to eq(6)
    end

    it "clamps to zero when crawler pageviews overshoot the topic view stats" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(
        :category_activity_daily_rollup,
        category: category,
        date: 2.days.ago,
        topics: 1,
        posts: 0,
        page_views: 3,
        likely_crawler_page_views: 9,
      )

      row =
        described_class.period_totals(
          prev_start: 14.days.ago.to_date,
          current_start: 7.days.ago.to_date,
          current_end: Time.zone.today,
        ).first

      expect(row.page_views_current).to eq(0)
    end

    it "counts likely crawler pageviews while crawler detection is disabled" do
      SiteSetting.improved_crawler_detection = false
      Fabricate(
        :category_activity_daily_rollup,
        category: category,
        date: 2.days.ago,
        topics: 0,
        posts: 0,
        page_views: 10,
        likely_crawler_page_views: 4,
      )

      row =
        described_class.period_totals(
          prev_start: 14.days.ago.to_date,
          current_start: 7.days.ago.to_date,
          current_end: Time.zone.today,
        ).first

      expect(row.page_views_current).to eq(10)
    end

    it "excludes categories outside the requested ids" do
      other_category = Fabricate(:category)
      Fabricate(:category_activity_daily_rollup, category: category)
      Fabricate(:category_activity_daily_rollup, category: other_category)

      rows =
        described_class.period_totals(
          prev_start: 7.days.ago.to_date,
          current_start: 3.days.ago.to_date,
          current_end: Time.zone.today,
          category_ids: [category.id],
        )

      expect(rows.map(&:id)).to eq([category.id])
    end

    it "excludes read restricted categories the user cannot see" do
      restricted = Fabricate(:private_category, group: Fabricate(:group))
      Fabricate(:category_activity_daily_rollup, category: category)
      Fabricate(:category_activity_daily_rollup, category: restricted)

      rows =
        described_class.period_totals(
          prev_start: 7.days.ago.to_date,
          current_start: 3.days.ago.to_date,
          current_end: Time.zone.today,
          secure_category_ids: [],
        )

      expect(rows.map(&:id)).to eq([category.id])
    end
  end
end
