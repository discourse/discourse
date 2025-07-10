# frozen_string_literal: true

RSpec.describe PostActionUsersController do
  before { SiteSetting.discourse_reactions_enabled = true }

  describe "post_action_users_list modifier for PostActionUsersController" do
    fab!(:current_user) { Fabricate(:user) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:post)

    before do
      DiscourseReactions::ReactionManager.new(
        reaction_value: "clap",
        user: user_1,
        post: post,
      ).toggle!

      DiscourseReactions::ReactionManager.new(
        reaction_value: DiscourseReactions::Reaction.main_reaction_id,
        user: user_2,
        post: post,
      ).toggle!
    end

    it "excludes users for a post who have a ReactionUser as well as a PostAction like" do
      sign_in(current_user)
      get "/post_action_users.json",
          params: {
            id: post.id,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["post_action_users"].map { |u| u["id"] }).to match_array(
        [user_2.id],
      )
    end
  end
end
