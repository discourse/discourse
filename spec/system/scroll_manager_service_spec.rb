# frozen_string_literal: true

describe "Ember route-scroll-manager service" do
  fab!(:topic)

  before do
    Fabricate(:admin)
    Fabricate.times(50, :post)
    Fabricate.times(20, :post, topic: topic)
  end

  let(:discovery) { PageObjects::Pages::Discovery.new }

  def current_scroll_y
    browser_page.evaluate("function(arguments) { return window.scrollY }", arg: [])
  end

  it "scrolls to top when navigating to new routes, and remembers scroll position when going back" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("body.navigation-topics").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(discovery.topic_list).to have_topics

    discovery.topic_list.scroll_to_topic_at_index(10)

    topic_list_scroll_y = current_scroll_y
    expect(topic_list_scroll_y).to be > 0

    browser_root
      .locator(".sidebar-section-link[data-link-name='all-categories']")
      .filter(visible: true)
      .press("Enter")

    expect(
      browser_root.locator("body.navigation-categories").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    browser_page.wait_for_function("expected => window.scrollY === expected", arg: 0)
    expect(current_scroll_y).to eq(0)

    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("body.navigation-topics").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(discovery.topic_list).to have_topics
    browser_page.wait_for_function(
      "expected => window.scrollY === expected",
      arg: topic_list_scroll_y,
    )
    expect(current_scroll_y).to eq(topic_list_scroll_y)

    # Clicking site logo triggers refresh and scrolls to top
    click_logo
    browser_page.wait_for_function("expected => window.scrollY === expected", arg: 0)
    expect(current_scroll_y).to eq(0)
  end

  it "scrolls to the top when navigating from a topic to the homepage" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#post_20").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_page.evaluate("() => window.scrollTo(0, document.scrollingElement.scrollHeight)")
    expect(current_scroll_y).to be > 0

    click_logo

    expect(
      browser_root.locator("body.navigation-topics").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(discovery.topic_list).to have_topics
    browser_page.wait_for_function("expected => window.scrollY === expected", arg: 0)
    expect(current_scroll_y).to eq(0)
  end
end
