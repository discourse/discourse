# frozen_string_literal: true

describe "Discovery list" do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:reply) { Fabricate(:post, topic: topics.first) }

  let(:discovery) { PageObjects::Pages::Discovery.new }

  def nth_topic_id(n)
    discovery
      .topic_list
      .locator(".topic-list-item:nth-of-type(#{n})")
      .filter(visible: true)
      .get_attribute("data-topic-id")
  end

  it "can sort a topic list by activity" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 10)
    newest_topic_id = nth_topic_id(1)

    browser_root.locator("th[data-sort-order='activity']").filter(visible: true).click

    expect(
      browser_root.locator("th[data-sort-order='activity'][aria-sort=ascending]").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(nth_topic_id(10)).to eq(newest_topic_id)

    browser_root.locator("th[data-sort-order='activity']").filter(visible: true).click
    expect(
      browser_root.locator("th[data-sort-order='activity'][aria-sort=descending]").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(nth_topic_id(1)).to eq(newest_topic_id)
  end

  it "can sort a topic list by replies" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 10)

    browser_root.locator("th[data-sort-order='posts']").filter(visible: true).click

    expect(
      browser_root.locator("th[data-sort-order='posts'][aria-sort=descending]").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(nth_topic_id(1)).to eq(reply.topic_id.to_s)

    browser_root.locator("th[data-sort-order='posts']").filter(visible: true).click
    expect(
      browser_root.locator("th[data-sort-order='posts'][aria-sort=ascending]").filter(
        visible: true,
      ),
    ).not_to have_count(0)
    expect(nth_topic_id(10)).to eq(reply.topic_id.to_s)
  end

  describe "bulk topic options" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { create_post(user: user, topic: topic) }
    fab!(:post2) { create_post(topic: topic) }

    it "shows and hides the bulk-select toggle for regular users" do
      sign_in(user)
      browser_page.goto("/unread").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      # The bulk select toggle should be visible, the user has an unread post
      browser_root.locator("button.bulk-select").filter(visible: true).click
      expect(
        browser_root.locator(".topic-list-body .bulk-select").filter(visible: true),
      ).not_to have_count(0)

      browser_root.locator("#navigation-bar .latest > a").filter(visible: true).click

      # No bulk select toggle or checkboxes
      # this action is not available for this user in /latest
      expect(
        browser_root.locator(".topic-list-body .bulk-select").filter(visible: true),
      ).to have_count(0)
      expect(browser_root.locator("button.bulk-select").filter(visible: true)).to have_count(0)
    end
  end

  it "doesn't preserve query parameters when navigating" do
    category = Fabricate(:category)
    topics.each { |t| t.update(category_id: category.id) }
    topics.last.update(closed: true)

    browser_page.goto("/latest?status=closed").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics(count: 1)
    discovery.category_drop.select_row_by_value(category.id)
    expect(discovery.topic_list).to have_topics(count: 10)
    expect(browser_page).to have_url("/c/#{category.slug}/#{category.id}")
  end
end
