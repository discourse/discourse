# frozen_string_literal: true

RSpec.describe DiscourseAi::AdminDashboard::AdminDashboardFacts do
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
    Fabricate.times(6, :post) # 6 topics, each with a single post (no replies)

    headlines = compute(start_date: 1.day.ago.to_date.to_s).fetch(:signals).map { |s| s[:headline] }

    expect(headlines).to include(
      match(/new member-created topics received no reply \(100% of member-created topics\)/),
    )
  end

  it "excludes staff-created topics from the unanswered signal" do
    user = Fabricate(:user)
    admin = Fabricate(:admin)
    moderator = Fabricate(:moderator)

    Fabricate.times(6, :post, user: user, created_at: 1.day.ago)
    Fabricate.times(3, :post, user: admin, created_at: 1.day.ago)
    Fabricate.times(3, :post, user: moderator, created_at: 1.day.ago)

    4.times do
      topic = Fabricate(:topic, user: user, created_at: 1.day.ago)
      Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago)
      Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago)
    end

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
    Fabricate(:topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, created_at: start_date)

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
    Fabricate.times(20, :topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(4, :topic, created_at: start_date)

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

    Fabricate(:topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: private_category, created_at: start_date)
    Fabricate.times(6, :private_message_topic, created_at: start_date)

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

    Fabricate(:topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: private_category, created_at: start_date)
    Fabricate.times(6, :private_message_topic, created_at: start_date)

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

    Fabricate(:topic, category: subcategory, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: subcategory, created_at: start_date)

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

    Fabricate(:topic, category: subcategory, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: subcategory, created_at: start_date)

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

    Fabricate(:topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: subcategory, created_at: start_date)
    Fabricate.times(6, :topic, category: private_category, created_at: start_date)

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

    Fabricate(:topic, created_at: Date.parse("2030-01-01"))
    Fabricate.times(6, :topic, category: subcategory, created_at: start_date)

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
    topic = Fabricate(:topic, title: "Welcome topic for visitors")
    Fabricate.times(
      50,
      :browser_pageview_event,
      topic_id: topic.id,
      normalized_referrer: "example.com",
      created_at: 1.day.ago,
    )

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
    selected_topic = Fabricate(:topic, title: "Selected landing topic")
    unselected_topic =
      Fabricate(:topic, category: unselected_category, title: "Unselected landing topic")
    private_topic = Fabricate(:topic, category: private_category, title: "Private landing topic")
    SiteSetting.ai_admin_dashboard_highlights_category_scope = "include"
    SiteSetting.ai_admin_dashboard_highlights_categories = selected_topic.category_id.to_s

    Fabricate.times(
      50,
      :browser_pageview_event,
      topic_id: selected_topic.id,
      normalized_referrer: "example.com",
      created_at: 1.day.ago,
    )
    Fabricate.times(
      55,
      :browser_pageview_event,
      topic_id: unselected_topic.id,
      normalized_referrer: "example.com",
      created_at: 1.day.ago,
    )
    Fabricate.times(
      60,
      :browser_pageview_event,
      topic_id: private_topic.id,
      normalized_referrer: "example.com",
      created_at: 1.day.ago,
    )

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
    admin = Fabricate(:admin)
    user = Fabricate(:user)
    Fabricate.times(12, :post, user: admin, created_at: 1.day.ago)
    Fabricate.times(8, :post, user: user, created_at: 1.day.ago)

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
    admin = Fabricate(:admin)
    user = Fabricate(:user)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_topic = Fabricate(:topic, category: private_category)

    Fabricate.times(6, :post, topic: private_topic, user: admin, created_at: 1.day.ago)
    Fabricate.times(8, :post, topic: private_topic, user: user, created_at: 1.day.ago)
    Fabricate.times(6, :private_message_post, user: admin, created_at: 1.day.ago)

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
