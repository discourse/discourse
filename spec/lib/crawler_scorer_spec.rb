# frozen_string_literal: true

RSpec.describe CrawlerScorer do
  let(:hostname) { Discourse.current_hostname }

  def make_event(opts = {})
    defaults = {
      url: "/t/topic/1",
      ip_address: "1.2.3.4",
      user_agent: "Mozilla/5.0",
      session_id: SecureRandom.hex(8),
      created_at: 30.minutes.ago,
      referrer: "https://#{hostname}/",
    }
    BrowserPageviewEvent.create!(defaults.merge(opts))
  end

  def score!
    described_class.score_anonymous!(window_start: 1.hour.ago, window_end: Time.now)
  end

  it "scores automation user agents at +50" do
    event = make_event(user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0")
    score!
    expect(event.reload.score).to eq(50)
  end

  it "scores known crawler ASNs at +35" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    score!
    expect(event.reload.score).to eq(35)
  end

  it "scores 60+ pageviews per identity in the window at +10" do
    session_id = "burst-session"
    base = 30.minutes.ago
    60.times { |i| make_event(session_id: session_id, created_at: base + (i * 30).seconds) }

    score!

    expect(
      BrowserPageviewEvent.where(session_id: session_id).pluck(:score).uniq,
    ).to contain_exactly(10)
  end

  it "scores session churn when one ip+ua spawns many short sessions" do
    10.times do |i|
      make_event(ip_address: "9.9.9.9", user_agent: "ScriptyBot/1.0", session_id: "churn-#{i}")
    end

    score!

    expect(BrowserPageviewEvent.where(ip_address: "9.9.9.9").pluck(:score).uniq).to contain_exactly(
      20,
    )
  end

  it "scores rapid navigation when the median gap is under 2 seconds" do
    session_id = "rapid-session"
    base = 30.minutes.ago
    11.times { |i| make_event(session_id: session_id, created_at: base + i.seconds) }

    score!

    expect(
      BrowserPageviewEvent.where(session_id: session_id).pluck(:score).uniq,
    ).to contain_exactly(15)
  end

  it "scores referrer discontinuity when most pageviews have no referrer" do
    session_id = "ref-session"
    5.times do
      make_event(
        ip_address: "5.5.5.5",
        user_agent: "RefBot/1.0",
        session_id: session_id,
        referrer: nil,
      )
    end

    score!

    expect(BrowserPageviewEvent.where(ip_address: "5.5.5.5").pluck(:score).uniq).to contain_exactly(
      10,
    )
  end

  it "ignores logged-in events" do
    user = Fabricate(:user)
    event = make_event(user_id: user.id, user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")

    score!

    expect(event.reload.score).to be_nil
  end

  it "ignores events outside the window" do
    event = make_event(user_agent: "HeadlessChrome/120", created_at: 2.hours.ago)

    score!

    expect(event.reload.score).to be_nil
  end

  it "only updates the score when the new value is higher" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120")
    event.update!(score: 80)

    score!

    expect(event.reload.score).to eq(80)
  end
end
