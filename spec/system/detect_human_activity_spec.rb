# frozen_string_literal: true

describe "Detect human activity" do
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }
  let(:discovery) { PageObjects::Pages::Discovery.new }

  before { SiteSetting.dashboard_improvements = true }

  def flush_engagement
    browser_page.then { |pw_page| pw_page.evaluate("window.dispatchEvent(new Event('pagehide'))") }
  end

  def engagement
    BrowserPageviewSessionEngagement.first
  end

  it "stores continuous mouse movement and time to first interaction" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 5)

    # `steps` interpolates the movement into many small mousemove events,
    # mimicking the continuous path a real pointer traces.
    browser_page.then { |pw_page| pw_page.mouse.move(400, 400, steps: 30) }
    browser_page.then { |pw_page| pw_page.keyboard.press("a") }
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.mouse_move_events).to be > 0
    expect(engagement.time_to_first_interaction_ms).to be_present
  end

  it "ignores teleporting mouse jumps" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 5)

    # Each move jumps straight to its destination with no intermediate events,
    # the way a script driving the cursor would. A real keypress and click meet
    # the two-category threshold so a snapshot is sent.
    browser_page.then do |pw_page|
      pw_page.mouse.move(50, 50)
      pw_page.mouse.move(600, 600)
      pw_page.mouse.move(50, 600)
      pw_page.keyboard.press("a")
      pw_page.mouse.down
      pw_page.mouse.up
    end
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.mouse_move_events).to eq(0)
    expect(engagement.key_events).to eq(1)
  end

  it "accumulates engaged duration while the tab is visible and focused" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 5)

    # An interaction is needed so a snapshot is sent; then stay engaged for a
    # beat before flushing so the duration has time to accumulate.
    browser_page.then do |pw_page|
      pw_page.keyboard.press("a")
      pw_page.mouse.down
      pw_page.mouse.up
      pw_page.wait_for_timeout(1200)
    end
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.engaged_seconds).to be >= 1
  end

  it "counts back/forward navigation" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 5)

    # In-app navigation uses pushState (no popstate); the back button does fire
    # popstate, which is what we count.
    discovery.topic_list.visit_topic(topics[0])
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_page.then { |pw_page| pw_page.keyboard.press("a") }
    flush_engagement

    try_until_success { expect(BrowserPageviewSessionEngagement.count).to eq(1) }
    expect(engagement.back_forward_events).to eq(1)
  end
end
