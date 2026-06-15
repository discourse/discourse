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
    )
  end

  it "classifies the trend from the metric deltas" do
    expect(compute[:trend]).to eq(:growing)
  end

  it "flags an unanswered-topics signal once it clears the threshold" do
    Fabricate.times(6, :post) # 6 topics, each with a single post (no replies)

    headlines = compute(start_date: 1.day.ago.to_date.to_s).fetch(:signals).map { |s| s[:headline] }

    expect(headlines).to include(match(/new topics received no reply/))
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
