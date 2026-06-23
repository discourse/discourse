# frozen_string_literal: true

describe "Detect human activity" do
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.persist_browser_pageview_events = true
  end

  # A snapshot is sent (via sendBeacon) when the page is hidden/unloaded; the
  # other trigger is the timer after the first interaction.
  def flush_engagement
    page.driver.with_playwright_page do |pw_page|
      pw_page.evaluate("window.dispatchEvent(new Event('pagehide'))")
      pw_page.wait_for_timeout(300)
    end
  end

  def engagement
    BrowserPageviewSessionEngagement.first
  end

  it "stores nothing for a passive page visit with no interaction" do
    visit("/")
    expect(discovery.topic_list).to have_topics(count: 5)

    flush_engagement

    expect(BrowserPageviewSessionEngagement.count).to eq(0)
  end

  it "stores continuous mouse movement and time to first interaction" do
    visit("/")
    expect(discovery.topic_list).to have_topics(count: 5)

    # `steps` interpolates the movement into many small mousemove events,
    # mimicking the continuous path a real pointer traces.
    page.driver.with_playwright_page { |pw_page| pw_page.mouse.move(400, 400, steps: 30) }
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.mouse_move_events).to be > 0
    expect(engagement.time_to_first_interaction_ms).to be_present
  end

  it "ignores teleporting mouse jumps" do
    visit("/")
    expect(discovery.topic_list).to have_topics(count: 5)

    # Each move jumps straight to its destination with no intermediate events,
    # the way a script driving the cursor would. A real keypress is added so a
    # snapshot is actually sent (teleports alone leave the session empty).
    page.driver.with_playwright_page do |pw_page|
      pw_page.mouse.move(50, 50)
      pw_page.mouse.move(600, 600)
      pw_page.mouse.move(50, 600)
      pw_page.keyboard.press("a")
    end
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.mouse_move_events).to eq(0)
    expect(engagement.key_events).to eq(1)
  end

  it "accumulates engaged duration while the tab is visible and focused" do
    visit("/")
    expect(discovery.topic_list).to have_topics(count: 5)

    # An interaction is needed so a snapshot is sent; then stay engaged for a
    # beat before flushing so the duration has time to accumulate.
    page.driver.with_playwright_page do |pw_page|
      pw_page.keyboard.press("a")
      pw_page.wait_for_timeout(1200)
    end
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.engaged_duration_ms).to be >= 1000
  end

  it "counts back/forward navigation" do
    visit("/")
    expect(discovery.topic_list).to have_topics(count: 5)

    # In-app navigation uses pushState (no popstate); the back button does fire
    # popstate, which is what we count.
    discovery.topic_list.visit_topic(topics[0])
    page.go_back
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.back_forward_events).to be > 0
  end
end
