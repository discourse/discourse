# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"
require_relative "../fabricators/reaction_user_fabricator.rb"

describe TopicViewSerializer do
  before { SiteSetting.discourse_reactions_enabled = true }

  context "with reactions and shadow like" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:post_1) { Fabricate(:post, user: user_1) }
    fab!(:post_2) { Fabricate(:post, user: user_1, topic: post_1.topic) }
    fab!(:otter) { Fabricate(:reaction, post: post_1, reaction_value: "otter") }
    fab!(:reaction_user1) { Fabricate(:reaction_user, reaction: otter, user: user_1) }
    fab!(:reaction_user2) { Fabricate(:reaction_user, reaction: otter, user: user_2) }
    fab!(:like_1) do
      Fabricate(
        :post_action,
        post: post_1,
        user: user_1,
        post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
      )
    end
    fab!(:like_2) do
      Fabricate(
        :post_action,
        post: post_1,
        user: user_2,
        post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
      )
    end
    let(:topic) { post_1.topic }
    let(:topic_view) { TopicView.new(topic) }

    it "shows valid reactions and user reactions" do
      SiteSetting.discourse_reactions_like_icon = "heart"
      SiteSetting.discourse_reactions_enabled_reactions =
        "laughing|heart|open_mouth|cry|angry|thumbsup|thumbsdown"
      json = TopicViewSerializer.new(topic_view, scope: Guardian.new(user_1), root: false).as_json
      expect(json[:valid_reactions]).to eq(
        %w[laughing heart open_mouth cry angry thumbsup thumbsdown].to_set,
      )
      expect(json[:post_stream][:posts][0][:reactions]).to eq(
        [{ id: "otter", type: :emoji, count: 2 }],
      )

      expect(json[:post_stream][:posts][0][:reaction_users_count]).to eq(2)
    end

    it "doesnt count deleted likes" do
      SiteSetting.discourse_reactions_like_icon = "heart"

      json = TopicViewSerializer.new(topic_view, scope: Guardian.new(user_2), root: false).as_json

      expect(json[:post_stream][:posts][1][:reaction_users_count]).to eq(0)

      DiscourseReactions::ReactionManager.new(
        reaction_value: "heart",
        user: user_2,
        post: post_2,
      ).toggle!
      json =
        TopicViewSerializer.new(
          TopicView.new(topic),
          scope: Guardian.new(user_2),
          root: false,
        ).as_json

      expect(json[:post_stream][:posts][1][:reaction_users_count]).to eq(1)

      DiscourseReactions::ReactionManager.new(
        reaction_value: "heart",
        user: user_2,
        post: post_2,
      ).toggle!
      json =
        TopicViewSerializer.new(
          TopicView.new(topic),
          scope: Guardian.new(user_2),
          root: false,
        ).as_json

      expect(json[:post_stream][:posts][1][:reaction_users_count]).to eq(0)
    end
  end

  describe "only shadow like" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:post_1) { Fabricate(:post, user: user_1) }
    fab!(:like_1) do
      Fabricate(
        :post_action,
        post: post_1,
        user: user_1,
        post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
      )
    end
    let(:topic) { post_1.topic }
    let(:topic_view) { TopicView.new(topic) }

    it "shows valid reactions and user reactions" do
      SiteSetting.discourse_reactions_like_icon = "heart"
      json = TopicViewSerializer.new(topic_view, scope: Guardian.new(user_1), root: false).as_json
      expect(json[:post_stream][:posts][0][:reactions]).to eq(
        [{ id: "heart", type: :emoji, count: 1 }],
      )

      expect(json[:post_stream][:posts][0][:reaction_users_count]).to eq(1)
    end
  end
end
