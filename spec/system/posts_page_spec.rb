# frozen_string_literal: true

describe "Posts page", type: :system do
  fab!(:post)
  fab!(:post_2) { Fabricate(:post) }
  fab!(:post_3) { Fabricate(:post) }
  fab!(:user)
  let(:posts_page) { PageObjects::Pages::Posts.new }

  before { sign_in(user) }

  it "renders the posts page with posts" do
    posts_page.visit
    expect(posts_page).to have_page_title
    expect(posts_page).to have_posts(3)
  end
end
