# frozen_string_literal: true

describe "User activity posts" do
  before_all { UserActionManager.enable }
  fab!(:user)

  fab!(:topic1) do
    Fabricate(:topic, title: "Title with &amp; characters and emoji :wave:").tap do |t|
      Fabricate.times(2, :post, topic: t, user:).each { |p| UserActionManager.post_created(p) }
    end
  end
  fab!(:topic2) do
    Fabricate(:topic).tap do |t|
      Fabricate.times(2, :post, topic: t, user:).each { |p| UserActionManager.post_created(p) }
    end
  end

  it "lists posts with correctly-formatted titles" do
    browser_page
      .goto("/u/#{user.username_lower}/activity/replies")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".stream-topic-title .title").filter(visible: true)).to have_count(
      2,
    )

    title_element =
      browser_root.locator(".stream-topic-title .title a[href*='/#{topic1.id}/']").filter(
        visible: true,
      )
    expect(title_element).to contain_text(
      browser_text_pattern("Title with &amp; characters and emoji"),
      useInnerText: true,
    )
    expect(
      title_element.locator("img.emoji[title='wave']").filter(visible: true),
    ).not_to have_count(0)
  end
end
