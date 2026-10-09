# frozen_string_literal: true

RSpec.describe DiscourseAi::AdminDashboard::AdminDashboardFacts do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)

  before do
    kpis = [
      { type: :new_signups, value: 100, previous_value: 50, percent_change: 100.0 },
      { type: :dau_mau, value: 20, previous_value: 19, percent_change: 5.0 },
      { type: :new_contributors, value: 40, previous_value: 38, percent_change: 5.0 },
      { type: :accepted_solutions, value: 30, previous_value: 10, percent_change: 200.0 },
    ]
    allow(AdminDashboardHighlights).to receive(:build).and_return({ kpis: kpis })
  end

  def compute(start_date: 30.days.ago.to_date.to_s, end_date: Date.current.to_s)
    described_class.compute(start_date: start_date, end_date: end_date)
  end

  def create_metric_topics(count, user:, **attributes)
    timestamp = Time.current
    Topic.insert_all!(
      Array.new(count) do
        Fabricate
          .build(
            :topic,
            user: user,
            last_post_user_id: user.id,
            bumped_at: timestamp,
            created_at: timestamp,
            updated_at: timestamp,
            **attributes,
          )
          .attributes
          .slice(*Topic.column_names)
          .except("id")
      end,
    )
  end

  def create_landing_events(count, topic:)
    BrowserPageviewEvent.insert_all!(
      Array.new(count) do
        Fabricate
          .build(
            :browser_pageview_event,
            topic_id: topic.id,
            normalized_referrer: "example.com",
            created_at: 1.day.ago,
          )
          .attributes
          .except("id")
      end,
    )
  end

  def create_ratio_posts(count, topic:, author:)
    first_post_number = topic.posts.maximum(:post_number).to_i + 1
    timestamp = 1.day.ago
    Post.insert_all!(
      Array.new(count) do |index|
        {
          topic_id: topic.id,
          user_id: author.id,
          post_number: first_post_number + index,
          post_type: Post.types[:regular],
          raw: "Staff ratio fixture",
          cooked: "<p>Staff ratio fixture</p>",
          created_at: timestamp,
          updated_at: timestamp,
          last_version_at: timestamp,
        }
      end,
    )
  end

  it "returns tile-consistent metrics with friendly labels" do
    facts = compute

    labels = facts[:metrics].map { |metric| metric[:label] }
    expect(labels).to include("new sign-ups", "new contributors")
    expect(facts[:metrics].find { |metric| metric[:label] == "new sign-ups" }).to include(
      value: 100,
      category: :acquisition,
    )
    expect(facts[:metrics].find { |metric| metric[:label] == "new contributors" }).to include(
      category: :participation,
    )
    expect(
      facts[:metrics].find { |metric| metric[:label] == "questions resolved (accepted solutions)" },
    ).to include(category: :support)
  end

  it "classifies the trend from the metric deltas" do
    expect(compute[:trend]).to eq(:growing)
  end

  it "flags an unanswered-topics signal once it clears the threshold" do
    create_metric_topics(6, user: user, posts_count: 1)

    headlines = compute(start_date: 1.day.ago.to_date.to_s).fetch(:signals).map { |s| s[:headline] }

    expect(headlines).to include(
      match(/new member-created topics received no reply \(100% of member-created topics\)/),
    )
  end

  it "excludes staff-created topics from the unanswered signal" do
    create_metric_topics(6, user: user, posts_count: 1, created_at: 1.day.ago)
    create_metric_topics(3, user: admin, posts_count: 1, created_at: 1.day.ago)
    create_metric_topics(3, user: moderator, posts_count: 1, created_at: 1.day.ago)
    create_metric_topics(4, user: user, posts_count: 2, created_at: 1.day.ago)

    unanswered_gap =
      compute(start_date: 2.days.ago.to_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :unanswered_gap }

    expect(unanswered_gap).to include(
      headline: "6 new member-created topics received no reply (60% of member-created topics)",
    )
  end

  it "reports when new-topic volume changes sharply" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    Fabricate(:topic, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |s| s[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were up 500% versus the previous period",
    )
  end

  it "reports when new-topic volume drops sharply from meaningful previous volume" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    create_metric_topics(20, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(4, user: user, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |s| s[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were down 80% versus the previous period",
    )
  end

  it "uses public categories for topic volume by default" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    private_category = Fabricate(:private_category, group: Fabricate(:group))

    Fabricate(:topic, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: private_category, created_at: start_date)
    Fabricate.times(6, :private_message_topic, user: user, recipient: admin, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to be_nil
  end

  it "uses all categories for topic volume when configured" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "all"

    Fabricate(:topic, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: private_category, created_at: start_date)
    Fabricate.times(6, :private_message_topic, user: user, recipient: admin, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were up 500% versus the previous period",
    )
  end

  it "includes subcategories in included topic volume" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    parent_category = Fabricate(:category)
    subcategory = Fabricate(:category, parent_category: parent_category)
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "include"
    SiteSetting.ai_admin_dashboard_highlights_categories = parent_category.id.to_s

    Fabricate(:topic, user: user, category: subcategory, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: subcategory, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were up 500% versus the previous period",
    )
  end

  it "uses only included categories for strict topic volume" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    parent_category = Fabricate(:category)
    subcategory = Fabricate(:category, parent_category: parent_category)
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "include_strict"
    SiteSetting.ai_admin_dashboard_highlights_categories = parent_category.id.to_s

    Fabricate(:topic, user: user, category: subcategory, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: subcategory, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to be_nil
  end

  it "excludes categories and subcategories from all topic volume" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    parent_category = Fabricate(:category)
    subcategory = Fabricate(:category, parent_category: parent_category)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "exclude"
    SiteSetting.ai_admin_dashboard_highlights_categories = parent_category.id.to_s

    Fabricate(:topic, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: subcategory, created_at: start_date)
    create_metric_topics(6, user: user, category: private_category, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were up 500% versus the previous period",
    )
  end

  it "excludes only configured categories from strict topic volume" do
    start_date = Date.parse("2030-01-08")
    end_date = Date.parse("2030-01-14")
    parent_category = Fabricate(:category)
    subcategory = Fabricate(:category, parent_category: parent_category)
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "exclude_strict"
    SiteSetting.ai_admin_dashboard_highlights_categories = parent_category.id.to_s

    Fabricate(:topic, user: user, created_at: Date.parse("2030-01-01"))
    create_metric_topics(6, user: user, category: subcategory, created_at: start_date)

    topic_volume =
      compute(start_date: start_date.to_s, end_date: end_date.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :topic_volume }

    expect(topic_volume).to include(
      category: :participation,
      headline: "New topics were up 500% versus the previous period",
    )
  end

  it "skips the raw landing-topic scan for long date ranges" do
    queries =
      track_sql_queries do
        compute(start_date: 1.year.ago.to_date.to_s, end_date: Date.current.to_s)
      end

    expect(queries.grep(/FROM browser_pageview_events e/)).to be_empty
  end

  it "reports the top external landing topic for three-month date ranges" do
    topic = Fabricate(:topic, user: user, title: "Welcome topic for visitors")
    create_landing_events(50, topic: topic)

    landing_topic =
      compute(start_date: 3.months.ago.to_date.to_s, end_date: Date.current.to_s)
        .fetch(:signals)
        .find { |s| s[:key] == :landing_topic }

    expect(landing_topic).to include(
      category: :acquisition,
      headline: 'External visitors mostly landed on "Welcome topic for visitors" (50 visits)',
    )
  end

  it "reports landing topics from included categories only" do
    unselected_category = Fabricate(:category)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    selected_topic = Fabricate(:topic, user: user, title: "Selected landing topic")
    unselected_topic =
      Fabricate(
        :topic,
        user: user,
        category: unselected_category,
        title: "Unselected landing topic",
      )
    private_topic =
      Fabricate(:topic, user: user, category: private_category, title: "Private landing topic")
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "include"
    SiteSetting.ai_admin_dashboard_highlights_categories = selected_topic.category_id.to_s

    create_landing_events(50, topic: selected_topic)
    create_landing_events(55, topic: unselected_topic)
    create_landing_events(60, topic: private_topic)

    landing_topic =
      compute(start_date: 3.months.ago.to_date.to_s, end_date: Date.current.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :landing_topic }

    expect(landing_topic).to include(
      category: :acquisition,
      headline: 'External visitors mostly landed on "Selected landing topic" (50 visits)',
    )
  end

  it "skips the raw staff-ratio post scan for long date ranges" do
    queries =
      track_sql_queries do
        compute(start_date: 1.year.ago.to_date.to_s, end_date: Date.current.to_s)
      end

    expect(queries.grep(/FROM posts p\s+JOIN users u/m)).to be_empty
  end

  it "reports staff post ratio for three-month date ranges" do
    topic = Fabricate(:topic, user: user)
    create_ratio_posts(12, topic: topic, author: admin)
    create_ratio_posts(8, topic: topic, author: user)

    staff_ratio =
      compute(start_date: 3.months.ago.to_date.to_s, end_date: Date.current.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :staff_ratio }

    expect(staff_ratio).to include(
      category: :participation,
      headline: "Staff wrote 60% of posts this period",
    )
  end

  it "uses public categories for staff ratio by default" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_topic = Fabricate(:topic, user: user, category: private_category)

    create_ratio_posts(6, topic: private_topic, author: admin)
    create_ratio_posts(8, topic: private_topic, author: user)
    pm = Fabricate(:private_message_topic, user: admin, recipient: user)
    create_ratio_posts(6, topic: pm, author: admin)

    staff_ratio =
      compute(start_date: 3.months.ago.to_date.to_s, end_date: Date.current.to_s)
        .fetch(:signals)
        .find { |signal| signal[:key] == :staff_ratio }

    expect(staff_ratio).to be_nil
  end

  it "reports a traffic spike WITHOUT a source when no referrer dominates" do
    base = 29.days.ago.to_date
    base.upto(Date.current) do |date|
      ApplicationRequest.create!(
        date: date,
        req_type: ApplicationRequest.req_types[:page_view_logged_in_browser],
        count: date == 20.days.ago.to_date ? 5000 : 100,
      )
    end

    spike = compute.fetch(:signals).find { |s| s[:key] == :traffic_spike }

    expect(spike).to be_present
    expect(spike[:headline]).to match(/Traffic spiked/)
    expect(spike[:category]).to eq(:acquisition)
    expect(spike[:headline]).not_to match(/driven by/)
  end

  it "names the source when one referrer dominates the spike day" do
    base = 29.days.ago.to_date
    spike_day = 20.days.ago.to_date
    base.upto(Date.current) do |date|
      ApplicationRequest.create!(
        date: date,
        req_type: ApplicationRequest.req_types[:page_view_logged_in_browser],
        count: date == spike_day ? 5000 : 100,
      )
    end
    BrowserPageviewReferrerDailyRollup.create!(
      date: spike_day,
      normalized_referrer: "news.ycombinator.com",
      count: 4000,
      logged_in_count: 0,
    )

    spike = compute.fetch(:signals).find { |s| s[:key] == :traffic_spike }

    expect(spike[:headline]).to include("news.ycombinator.com")
  end

  it "does not report the site's own hostname as the traffic spike source" do
    allow(Discourse).to receive(:current_hostname).and_return("meta.discourse.org")
    base = 29.days.ago.to_date
    spike_day = 20.days.ago.to_date
    base.upto(Date.current) do |date|
      ApplicationRequest.create!(
        date: date,
        req_type: ApplicationRequest.req_types[:page_view_logged_in_browser],
        count: date == spike_day ? 5000 : 100,
      )
    end
    BrowserPageviewReferrerDailyRollup.create!(
      date: spike_day,
      normalized_referrer: "meta.discourse.org",
      count: 4000,
      logged_in_count: 0,
    )

    spike = compute.fetch(:signals).find { |s| s[:key] == :traffic_spike }

    expect(spike[:headline]).not_to include("meta.discourse.org")
    expect(spike[:headline]).not_to include("external referrer")
  end

  it "does not report a same-site subfolder referrer as the traffic spike source" do
    allow(Discourse).to receive(:current_hostname).and_return("meta.discourse.org")
    base = 29.days.ago.to_date
    spike_day = 20.days.ago.to_date
    base.upto(Date.current) do |date|
      ApplicationRequest.create!(
        date: date,
        req_type: ApplicationRequest.req_types[:page_view_logged_in_browser],
        count: date == spike_day ? 5000 : 100,
      )
    end
    BrowserPageviewReferrerDailyRollup.create!(
      date: spike_day,
      normalized_referrer: "meta.discourse.org/forum/latest",
      count: 4000,
      logged_in_count: 0,
    )

    spike = compute.fetch(:signals).find { |s| s[:key] == :traffic_spike }

    expect(spike[:headline]).not_to include("meta.discourse.org")
    expect(spike[:headline]).not_to include("external referrer")
  end
end
