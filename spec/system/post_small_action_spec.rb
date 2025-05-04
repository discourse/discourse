# frozen_string_literal: true

describe "Post small actions", type: :system do
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

    find(".search-dropdown").click
    find("#icon-search-input").fill_in(with: "special")

    find(".search-menu-assistant-item:nth-child(2)").click

    # has highlighting for the regular post
    expect(page).to have_css(".topic-post.regular .highlighted")

    # has highlighting for the small action post
    expect(page).to have_css(".small-action .highlighted")
  end

  it "applies animated gif decorations" do
    post =
      Fabricate(:small_action, raw: "Enjoy this gif", topic: topic, action_code: "closed.enabled")

    topic_page.visit_topic(topic)
    expect(topic_page).to have_post_number(post.post_number)

    find(".small-action-buttons .small-action-edit").click
    attach_file file_from_fixtures("animated.gif").path do
      composer.click_toolbar_button("upload")
    end

    expect(composer).to have_no_in_progress_uploads
    composer.submit

    expect(page).to have_css(".small-action .pausable-animated-image", wait: 5)
  end
end
