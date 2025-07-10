# frozen_string_literal: true

describe "Reactions | Activity", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.discourse_reactions_enabled = true

    sign_in(current_user)
  end

  context "when current user reacts to a post" do
    fab!(:post_1) { Fabricate(:post) }
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

    context "when unicode usernames is enabled " do
      before do
        SiteSetting.external_system_avatars_enabled = true
        SiteSetting.external_system_avatars_url =
          "/letter_avatar_proxy/v4/letter/{first_letter}/{color}/{size}.png"
        SiteSetting.unicode_usernames = true
      end

      context "when prioritize_full_name_in_ux SiteSetting is true" do
        before do
          SiteSetting.prioritize_full_name_in_ux = true
          stub_request(
            :get,
            "https://avatars.discourse-cdn.com/v4/letter/b/dbc845/48.png",
          ).to_return(status: 200, body: "image", headers: {})

          stub_request(
            :get,
            "https://avatars.discourse-cdn.com/v4/letter/b/90ced4/48.png",
          ).to_return(status: 200, body: "image", headers: {})

          stub_request(
            :get,
            "https://avatars.discourse-cdn.com/v4/letter/b/90ced4/24.png",
          ).to_return(status: 200, body: "image", headers: {})

          stub_request(
            :get,
            "https://avatars.discourse-cdn.com/v4/letter/b/90ced4/144.png",
          ).to_return(status: 200, body: "image", headers: {})

          stub_request(
            :get,
            "https://avatars.discourse-cdn.com/v4/letter/b/9de053/48.png",
          ).to_return(status: 200, body: "image", headers: {})
        end

        it "shows the name of the mentioned user instead of the username" do
          unicode_user = Fabricate(:user)
          post_2 =
            Fabricate(:post, raw: "This is a test post with a mention @#{unicode_user.username}")
          DiscourseReactions::ReactionManager.new(
            reaction_value: "clap",
            user: current_user,
            post: post_2,
          ).toggle!

          visit("/u/#{current_user.username}/activity/reactions")

          post = find(".user-stream-item [data-post-id='#{post_2.id}']")
          expect(page).to have_css(".user-stream-item [data-post-id='#{post_2.id}']")
          expect(post).to have_content("@Bruce Wayne")
        end
      end
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
