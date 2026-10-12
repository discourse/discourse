# frozen_string_literal: true

describe "Focusing the target post when opening a topic" do
  fab!(:topic)
  fab!(:posts) { Fabricate.times(30, :post, topic:) }
  fab!(:target_post) { posts[19] }

  it "focuses the post when the page is loaded at that post" do
    visit(target_post.url)

    expect(page).to have_css("#post_#{target_post.post_number} .topic-body:focus")
  end

  it "focuses the post when following a link to it from another topic" do
    linking_post = Fabricate(:post, raw: "See #{Discourse.base_url}#{target_post.url}")
    visit(linking_post.topic.url)

    find("#post_1 .cooked a[href*='/t/']").click

    expect(page).to have_css("#post_#{target_post.post_number} .topic-body:focus")
  end

  it "focuses the post when following a link to it within the same topic" do
    posts[0].update!(raw: "See #{Discourse.base_url}#{target_post.url}")
    posts[0].rebake!
    visit(topic.url)

    find("#post_1 .cooked a[href*='/t/']").click

    expect(page).to have_css("#post_#{target_post.post_number} .topic-body:focus")
  end

  it "keeps focus on the post when a user tip appears" do
    SiteSetting.enable_user_tips = true
    sign_in(Fabricate(:user))
    visit(target_post.url)

    expect(PageObjects::Components::Tooltips.new("user-tip")).to be_present
    expect(page).to have_css("#post_#{target_post.post_number} .topic-body:focus")
  end
end
