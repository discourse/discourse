# frozen_string_literal: true

describe "Reactions | Activity", type: :system do
  fab!(:current_user, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true

    sign_in(current_user)
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
