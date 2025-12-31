# frozen_string_literal: true

describe TopicsController do
  fab!(:post)

  fab!(:laughing_reaction) { Fabricate(:reaction, post: post, reaction_value: "laughing") }
  fab!(:open_mouth_reaction) { Fabricate(:reaction, post: post, reaction_value: "open_mouth") }
  fab!(:hugs_reaction) { Fabricate(:reaction, post: post, reaction_value: "hugs") }

  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:user_4, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions =
      "laughing|open_mouth|cry|angry|thumbsup|hugs"
  end

  describe "#show" do
    context "when user has reacted but like_count is 0 and undo window passed" do
      fab!(:reaction) { Fabricate(:reaction, post:) }
      fab!(:reaction_user) { Fabricate(:reaction_user, reaction:, user: user_1, post:) }
      fab!(:like_action) do
        Fabricate(
          :post_action,
          user: user_1,
          post:,
          post_action_type_id: PostActionType.types[:like],
          created_at: 1.day.ago,
        )
      end

      before do
        SiteSetting.post_undo_action_window_mins = 10
        post.update_column(:like_count, 0)
      end

      it "includes the like action in actions_summary with acted flag" do
        sign_in(user_1)

        get "/t/#{post.topic_id}.json"
        expect(response.status).to eq(200)

        post_json = response.parsed_body["post_stream"]["posts"].find { |p| p["id"] == post.id }
        like_action_summary =
          post_json["actions_summary"].find { |a| a["id"] == PostActionType.types[:like] }

        expect(like_action_summary).to be_present
        expect(like_action_summary["acted"]).to eq(true)
        expect(like_action_summary["can_undo"]).to be_nil
      end
    end

    it "does not generate N+1 queries" do
      sign_in(user_1)

      queries = track_sql_queries { get "/t/#{post.topic_id}.json" }
      count = queries.filter { |q| q.include?("reactions") }.size

      Fabricate(:reaction_user, reaction: laughing_reaction, user: user_1, post: post)
      Fabricate(:reaction_user, reaction: laughing_reaction, user: user_2, post: post)

      queries = track_sql_queries { get "/t/#{post.topic_id}.json" }
      expect(queries.filter { |q| q.include?("reactions") }.size).to eq(count)

      Fabricate(:reaction_user, reaction: hugs_reaction, user: user_3, post: post)
      Fabricate(:reaction_user, reaction: open_mouth_reaction, user: user_4, post: post)

      queries = track_sql_queries { get "/t/#{post.topic_id}.json" }
      expect(queries.filter { |q| q.include?("reactions") }.size).to eq(count)
    end
  end
end
