# frozen_string_literal: true

describe "Discovery heading accessibility" do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:tag) { Fabricate(:tag, name: "help") }

  fab!(:topic_in_category) { Fabricate(:topic, category: category) }
  fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
  fab!(:topic_in_category_tagged) { Fabricate(:topic, category: category, tags: [tag]) }

  it "shows correct heading for category view" do
    browser_page
      .goto("/c/#{category.slug}/#{category.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("Latest topics in General")],
      useInnerText: true,
    )
  end

  it "shows correct heading for tagged view" do
    browser_page.goto("/tags/#{tag.name}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("Latest topics tagged help")],
      useInnerText: true,
    )
  end

  it "shows correct heading for category + tag view" do
    browser_page
      .goto("/tags/c/#{category.slug}/#{category.id}/#{tag.name}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("Latest topics in General tagged help")],
      useInnerText: true,
    )
  end

  it "shows correct heading for no tags view" do
    browser_page.goto("/tag/none").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("Latest topics without tags")],
      useInnerText: true,
    )
  end

  it "shows default heading for latest topics" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("All latest topics")],
      useInnerText: true,
    )
  end

  it "shows heading for all categories view" do
    browser_page.goto("/categories").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("All categories")],
      useInnerText: true,
    )
  end

  it "shows heading for bookmarked topics" do
    sign_in(Fabricate(:user))

    browser_page.goto("/bookmarks").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("All topics you’ve bookmarked")],
      useInnerText: true,
    )
  end

  it "shows heading for posted topics" do
    sign_in(Fabricate(:user))

    browser_page.goto("/posted").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("h1").filter(visible: true)).to contain_text(
      [browser_text_pattern("All topics you’ve posted in")],
      useInnerText: true,
    )
  end
end
