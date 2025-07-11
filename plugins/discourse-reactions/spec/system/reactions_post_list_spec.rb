# frozen_string_literal: true

describe "Reactions | Post reaction user list", type: :system, js: true do
  fab!(:current_user, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:post) { Fabricate(:post, user: current_user) }

  let(:reactions_list) do
    PageObjects::Components::PostReactionsList.new("#post_#{post.post_number}")
  end

  before do
    SiteSetting.discourse_reactions_enabled = true

    DiscourseReactions::ReactionManager.new(
      reaction_value: "heart",
      user: user_2,
      post: post,
    ).toggle!
    DiscourseReactions::ReactionManager.new(
      reaction_value: "clap",
      user: user_3,
      post: post,
    ).toggle!
  end

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
      it "shows a list of users who have reacted to a post on hover for likes and each reaction" do
        sign_in(current_user)
        visit(post.url)

        expect(reactions_list).to have_reaction("heart")
        expect(reactions_list).to have_reaction("clap")

        reactions_list.hover_over_reaction("heart")
        expect(reactions_list).to have_users_for_reaction("heart", [user_2.username])

        # hover on something else to clear the current hover
        page.find("#site-logo").hover

        reactions_list.hover_over_reaction("clap")
        expect(reactions_list).to have_users_for_reaction("clap", [user_3.username])
      end

      it "shows more info about reactions when clicking" do
        visit(post.url)
        expect(reactions_list).to have_reaction("heart")
        reactions_list.click_reaction("heart")

        expect(page).to have_css(".discourse-reactions-state-panel")
        find(".discourse-reactions-state-panel [data-user-card=#{user_2.username}]").click

        expect(page).to have_css(".user-card.user-card-#{user_2.username}")
      end

      context "when the site allows anonymous users to like posts" do
        before do
          SiteSetting.allow_anonymous_mode = true
          SiteSetting.allow_likes_in_anonymous_mode = true
        end

        it "shows a list of users who have liked a post on hover for unauthenticated users" do
          visit(post.url)

          expect(reactions_list).to have_reaction("heart")

          reactions_list.hover_over_reaction("heart")
          expect(reactions_list).to have_users_for_reaction("heart", [user_2.username])
        end

        it "shows a list of users who have liked a post on hover for authenticated users posting anonymously" do
          anonymous_user = Fabricate(:anonymous)
          sign_in(anonymous_user)
          visit(post.url)

          expect(reactions_list).to have_reaction("heart")

          reactions_list.hover_over_reaction("heart")
          expect(reactions_list).to have_users_for_reaction("heart", [user_2.username])
        end
      end
    end
  end
end
