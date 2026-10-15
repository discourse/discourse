# frozen_string_literal: true

describe "Post small actions" do
  fab!(:admin)
  fab!(:topic)
  fab!(:first_post) do
    Fabricate(:post, topic: topic, raw: "This is a special post with special stuff")
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    sign_in(admin)
    Jobs.run_immediately!
  end

  it "applies search highlight decorations" do
    post = Fabricate(:small_action, raw: "This small post is also special", topic: topic)

    topic_page.visit_topic(topic)
    expect(topic_page).to have_post_number(post.post_number)

    browser_root.locator(".search-dropdown").filter(visible: true).click
    browser_root.locator("#icon-search-input").filter(visible: true).fill("special")

    browser_root.locator(".search-menu-assistant-item:nth-child(2)").filter(visible: true).click

    # has highlighting for the regular post
    expect(
      browser_root.locator(".topic-post.regular .highlighted").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    # has highlighting for the small action post
    expect(
      browser_root.locator(".small-action .highlighted").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "applies animated gif decorations" do
    post =
      Fabricate(:small_action, raw: "Enjoy this gif", topic: topic, action_code: "closed.enabled")

    topic_page.visit_topic(topic)
    expect(topic_page).to have_post_number(post.post_number)

    browser_root.locator(".small-action-buttons .small-action-edit").filter(visible: true).click

    browser_root.locator(
      "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
    ).set_input_files(file_from_fixtures("animated.gif").path)

    expect(composer).to have_no_in_progress_uploads
    composer.submit

    expect(
      browser_root.locator(".small-action .pausable-animated-image").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0, timeout: 5 * 1000)
  end
end
