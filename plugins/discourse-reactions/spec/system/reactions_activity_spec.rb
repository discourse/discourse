# frozen_string_literal: true

describe "Reactions | Activity", type: :system do
  fab!(:current_user, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true

    sign_in(current_user)
  end

  describe "reactions received pagination" do
    fab!(:reactor, :user)

    it "loads more unique reactions when scrolling" do
      # Create more posts than fit on one page to trigger pagination
      page_size = DiscourseReactions::CustomReactionsController::PAGE_SIZE
      posts = Fabricate.times(page_size + 5, :post, user: current_user)
      posts.each do |post|
        DiscourseReactions::ReactionManager.new(
          reaction_value: "clap",
          user: reactor,
          post: post,
        ).toggle!
      end

      visit("/u/#{current_user.username}/notifications/reactions-received")

      initial_items = page.all(".user-stream-item")
      expect(initial_items.count).to be < posts.count

      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

      expect(page).to have_css(".user-stream-item", count: posts.count, wait: 5)

      post_ids = page.all(".user-stream-item [data-post-id]").map { |el| el["data-post-id"] }
      expect(post_ids.uniq.count).to eq(posts.count)
    end
  end

  context "when current user reacts to a post" do
    fab!(:post_1, :post)
    before do
      DiscourseReactions::ReactionManager.new(
        reaction_value: "clap",
        user: current_user,
        post: post_1,
      ).toggle!
    end

    it "shows in activity" do
      visit("/u/#{current_user.username}/activity/reactions")

      expect(page).to have_css(".user-stream-item [data-post-id='#{post_1.id}']")
    end

    context "when the associated post is deleted" do
      before { post_1.trash! }

      it "doesn't show it" do
        visit("/u/#{current_user.username}/activity/reactions")

        expect(page).to have_no_css(".user-stream-item [data-post-id='#{post_1.id}']")
      end
    end

    context "when the associated topic is deleted" do
      before { post_1.topic.trash! }

      it "doesn't show it" do
        visit("/u/#{current_user.username}/activity/reactions")

        expect(page).to have_no_css(".user-stream-item [data-post-id='#{post_1.id}']")
      end
    end
  end
end
