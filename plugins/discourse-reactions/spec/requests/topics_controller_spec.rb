# frozen_string_literal: true

require "rails_helper"

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
