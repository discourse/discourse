# frozen_string_literal: true

RSpec.describe "Viewport-based mobile mode" do
  it "updates classes at runtime" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("html.desktop-view").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("html.mobile-view").filter(visible: true)).to have_count(0)

    resize_window(width: 400) do
      expect(browser_root.locator("html.mobile-view").filter(visible: true)).not_to have_count(0)
      expect(browser_root.locator("html.desktop-view").filter(visible: true)).to have_count(0)
    end
  end

  context "when resizing viewport while on a topic page" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:) }

    it "handles navigation after resize from mobile to desktop" do
      resize_window(width: 400) do
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(browser_root.locator("html.mobile-view").filter(visible: true)).not_to have_count(0)
      end

      click_logo
      expect(browser_root.locator(".topic-list").filter(visible: true)).not_to have_count(0)
    end

    it "handles navigation after resize from desktop to mobile" do
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("html.desktop-view").filter(visible: true)).not_to have_count(0)

      resize_window(width: 400) do
        expect(browser_root.locator("html.mobile-view").filter(visible: true)).not_to have_count(0)
        click_logo
        expect(browser_root.locator(".topic-list").filter(visible: true)).not_to have_count(0)
      end
    end
  end
end
