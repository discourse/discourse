# frozen_string_literal: true

describe "Focusing the target post when opening a topic" do
  fab!(:topic)
  fab!(:posts) { Fabricate.times(30, :post, topic:) }
  fab!(:target_post) { posts[19] }

  it "focuses the post when the page is loaded at that post" do
    browser_page.goto(target_post.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("#post_#{target_post.post_number} .topic-body:focus").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end

  it "focuses the post when following a link to it from another topic" do
    linking_post = Fabricate(:post, raw: "See #{Discourse.base_url}#{target_post.url}")
    browser_page.goto(linking_post.topic.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator("#post_1 .cooked a[href*='/t/']").filter(visible: true).click

    expect(
      browser_root.locator("#post_#{target_post.post_number} .topic-body:focus").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end

  it "focuses the post when following a link to it within the same topic" do
    posts[0].update!(raw: "See #{Discourse.base_url}#{target_post.url}")
    posts[0].rebake!
    browser_page.goto(topic.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator("#post_1 .cooked a[href*='/t/']").filter(visible: true).click

    expect(
      browser_root.locator("#post_#{target_post.post_number} .topic-body:focus").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end

  it "keeps focus on the post when a user tip appears" do
    SiteSetting.enable_user_tips = true
    sign_in(Fabricate(:user))
    browser_page.goto(target_post.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(PageObjects::Components::Tooltips.new("user-tip")).to be_present
    expect(
      browser_root.locator("#post_#{target_post.post_number} .topic-body:focus").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end
end
