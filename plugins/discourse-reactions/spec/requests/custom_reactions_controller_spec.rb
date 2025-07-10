# frozen_string_literal: true

require "rails_helper"

describe DiscourseReactions::CustomReactionsController do
  fab!(:post_1) { Fabricate(:post) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:user_4) { Fabricate(:user) }
  fab!(:user_5) { Fabricate(:user) }
  fab!(:admin)
  fab!(:post_2) { Fabricate(:post, user: user_1) }
  fab!(:private_topic) { Fabricate(:private_message_topic, user: user_2, recipient: admin) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic) }
  fab!(:whisper_post) do
    Fabricate(:post, topic: Fabricate(:topic), post_type: Post.types[:whisper])
  end
  fab!(:laughing_reaction) { Fabricate(:reaction, post: post_2, reaction_value: "laughing") }
  fab!(:open_mouth_reaction) { Fabricate(:reaction, post: post_2, reaction_value: "open_mouth") }
  fab!(:hugs_reaction) { Fabricate(:reaction, post: post_2, reaction_value: "hugs") }
  fab!(:hugs_reaction_private) { Fabricate(:reaction, post: private_post, reaction_value: "hugs") }
  fab!(:laughing_reaction_whisper) do
    Fabricate(:reaction, post: whisper_post, reaction_value: "laughing")
  end
  fab!(:like) do
    Fabricate(
      :post_action,
      post: post_2,
      user: user_5,
      post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
    )
  end
  fab!(:reaction_user_1) do
    Fabricate(:reaction_user, reaction: laughing_reaction, user: user_2, post: post_2)
  end
  fab!(:reaction_user_2) do
    Fabricate(:reaction_user, reaction: laughing_reaction, user: user_1, post: post_2)
  end
  fab!(:reaction_user_3) do
    Fabricate(:reaction_user, reaction: hugs_reaction, user: user_4, post: post_2)
  end
  fab!(:reaction_user_4) do
    Fabricate(:reaction_user, reaction: open_mouth_reaction, user: user_3, post: post_2)
  end
  fab!(:reaction_user_5) do
    Fabricate(:reaction_user, reaction: hugs_reaction_private, user: admin, post: private_post)
  end
  fab!(:reaction_user_6) do
    Fabricate(:reaction_user, reaction: laughing_reaction_whisper, user: user_2, post: whisper_post)
  end

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_like_icon = "heart"
    SiteSetting.discourse_reactions_enabled_reactions =
      "laughing|open_mouth|cry|angry|thumbsup|hugs"
    user_2.user_stat.update!(post_count: 1)
  end

  describe "#toggle" do
    let(:payload_with_user) { [{ "id" => "hugs", "type" => "emoji", "count" => 1 }] }
    let(:api_key) { Fabricate(:api_key, user: admin, created_by: admin) }

    it "toggles reaction" do
      sign_in(user_1)
      expected_payload = [{ "id" => "hugs", "type" => "emoji", "count" => 1 }]
      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
      end.to change { DiscourseReactions::Reaction.count }.by(1).and change {
              DiscourseReactions::ReactionUser.count
            }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["reactions"]).to eq(expected_payload)

      reaction = DiscourseReactions::Reaction.last
      expect(reaction.reaction_value).to eq("hugs")
      expect(reaction.reaction_users_count).to eq(1)

      sign_in(user_2)
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
      reaction = DiscourseReactions::Reaction.last
      expect(reaction.reaction_value).to eq("hugs")
      expect(reaction.reaction_users_count).to eq(2)

      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
      end.to not_change { DiscourseReactions::Reaction.count }.and change {
              DiscourseReactions::ReactionUser.count
            }.by(-1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["reactions"]).to eq(expected_payload)

      sign_in(user_1)
      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
      end.to change { DiscourseReactions::Reaction.count }.by(-1).and change {
              DiscourseReactions::ReactionUser.count
            }.by(-1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["reactions"]).to eq([])
    end

    it "publishes MessageBus messages" do
      sign_in(user_1)

      messages =
        MessageBus.track_publish("/topic/#{post_1.topic.id}") do
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
        end
      expect(messages.count).to eq(6)
      expect(messages.map(&:data).map { |m| m[:type] }.uniq).to match_array(
        %i[acted liked unliked stats],
      )

      messages =
        MessageBus.track_publish("/topic/#{post_1.topic.id}/reactions") do
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
        end
      expect(messages.count).to eq(2)
      expect(messages.map(&:channel).uniq.first).to eq("/topic/#{post_1.topic.id}/reactions")
      expect(messages[0].data[:reactions]).to contain_exactly("cry")
      expect(messages[1].data[:reactions]).to contain_exactly("cry")

      messages =
        MessageBus.track_publish("/topic/#{post_1.topic.id}/reactions") do
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/angry/toggle.json"
        end
      expect(messages.count).to eq(2)
      expect(messages.map(&:channel).uniq.first).to eq("/topic/#{post_1.topic.id}/reactions")
      expect(messages[0].data[:reactions]).to contain_exactly("cry")
      expect(messages[1].data[:reactions]).to contain_exactly("cry", "angry")
    end

    it "publishes MessageBus messages securely" do
      sign_in(user_1)
      messages =
        MessageBus.track_publish("/topic/#{private_post.topic.id}/reactions") do
          put "/discourse-reactions/posts/#{private_post.id}/custom-reactions/cry/toggle.json",
              headers: {
                "HTTP_API_KEY" => api_key.key,
                "HTTP_API_USERNAME" => api_key.user.username,
              }
        end
      user_1_messages = messages.find { |m| m.user_ids.include?(user_1.id) }
      expect(messages.count).to eq(1)
      expect(user_1_messages).to eq(nil)
    end

    it "errors when reaction is invalid" do
      sign_in(user_1)
      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/invalid-reaction/toggle.json"
      end.not_to change { DiscourseReactions::Reaction.count }

      expect(response.status).to eq(422)
    end
  end

  describe "#reactions_given" do
    fab!(:private_topic) { Fabricate(:private_message_topic, user: user_2) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic) }
    fab!(:secure_group) { Fabricate(:group) }
    fab!(:secure_category) { Fabricate(:private_category, group: secure_group) }
    fab!(:secure_topic) { Fabricate(:topic, category: secure_category) }
    fab!(:secure_post) { Fabricate(:post, topic: secure_topic) }
    fab!(:private_reaction) { Fabricate(:reaction, post: private_post, reaction_value: "hugs") }
    fab!(:secure_reaction) { Fabricate(:reaction, post: secure_post, reaction_value: "hugs") }
    fab!(:private_topic_reaction_user) do
      Fabricate(:reaction_user, reaction: private_reaction, user: user_2, post: private_post)
    end
    fab!(:secure_topic_reaction_user) do
      Fabricate(:reaction_user, reaction: secure_reaction, user: user_2, post: secure_post)
    end

    it "returns reactions given by a user" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }
      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed[0]["user"]["id"]).to eq(user_2.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(laughing_reaction.id)
    end

    it "does not return reactions for private messages" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }

      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).not_to include(
        private_post.id,
      )
    end

    it "returns reactions for private messages of current user" do
      sign_in(user_2)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }
      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).to include(
        private_post.id,
      )
    end

    it "does not return reactions for secure categories" do
      secure_group.add(user_2)
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }
      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).not_to include(
        secure_post.id,
      )

      secure_group.add(user_1)
      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }
      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).to include(secure_post.id)

      sign_in(user_2)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }
      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).to include(secure_post.id)
    end

    it "does not return reactions for whispers if the user is not in whispers_allowed_groups" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }

      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).not_to include(
        whisper_post.id,
      )

      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
      Group.refresh_automatic_groups!

      get "/discourse-reactions/posts/reactions.json", params: { username: user_2.username }

      parsed = response.parsed_body
      expect(response.parsed_body.map { |reaction| reaction["post_id"] }).to include(
        whisper_post.id,
      )
    end

    describe "a post with one of your reactions has been deleted" do
      fab!(:deleted_post) { Fabricate(:post) }
      fab!(:kept_post) { Fabricate(:post) }
      fab!(:user)
      fab!(:reaction_on_deleted_post) do
        Fabricate(:reaction, post: deleted_post, reaction_value: "laughing")
      end
      fab!(:reaction_on_kept_post) do
        Fabricate(:reaction, post: kept_post, reaction_value: "laughing")
      end
      fab!(:reaction_user_on_deleted_post) do
        Fabricate(
          :reaction_user,
          reaction: reaction_on_deleted_post,
          user: user,
          post: deleted_post,
        )
      end
      fab!(:reaction_user_on_kept_post) do
        Fabricate(:reaction_user, reaction: reaction_on_kept_post, user: user, post: kept_post)
      end

      it "doesn’t return the deleted post/reaction" do
        sign_in(user)

        get "/discourse-reactions/posts/reactions.json", params: { username: user.username }
        parsed = response.parsed_body
        expect(parsed.length).to eq(2)

        PostDestroyer.new(Discourse.system_user, deleted_post).destroy

        get "/discourse-reactions/posts/reactions.json", params: { username: user.username }
        parsed = response.parsed_body

        expect(parsed.length).to eq(1)
        expect(parsed[0]["post_id"]).to eq(kept_post.id)
      end
    end

    context "when op containing reactions is destroyed" do
      fab!(:topic) { create_topic }
      fab!(:op) { Fabricate(:post, topic: topic) }

      it "doesn’t return the reactions from deleted topic" do
        deleted_topic_id = topic.id
        sign_in(user_1)
        put "/discourse-reactions/posts/#{op.id}/custom-reactions/hugs/toggle.json"
        get "/discourse-reactions/posts/reactions.json", params: { username: user_1.username }

        expect(response.parsed_body.length).to eq(2)

        PostDestroyer.new(Discourse.system_user, op).destroy
        get "/discourse-reactions/posts/reactions.json", params: { username: user_1.username }

        parsed = response.parsed_body
        expect(parsed.length).to eq(1)
        expect(parsed[0]["topic_id"]).to_not eq(deleted_topic_id)
      end
    end
  end

  describe "#reactions_received" do
    it "returns reactions received by a user when current user is admin" do
      sign_in(admin)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
          }
      parsed = response.parsed_body

      expect(parsed[0]["user"]["id"]).to eq(user_3.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(open_mouth_reaction.id)
    end

    it "does not return reactions received by a user when current user is not an admin" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_2.username,
          }

      expect(response.status).to eq(403)
    end

    it "filters by acting username" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
            acting_username: user_4.username,
          }
      parsed = response.parsed_body

      expect(parsed.size).to eq(1)
      expect(parsed[0]["user"]["id"]).to eq(user_4.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(hugs_reaction.id)
    end

    it "include likes" do
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
            include_likes: true,
            acting_username: user_5.username,
          }

      parsed = response.parsed_body

      expect(parsed.size).to eq(1)
      expect(parsed[0]["user"]["id"]).to eq(user_5.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(like.id)
    end

    it "does not include reactions which also count as a like when include_likes is true" do
      sign_in(user_1)
      other_post = Fabricate(:post, user: user_1)
      laugh = Fabricate(:reaction_user, reaction: laughing_reaction, user: user_5, post: other_post)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
            include_likes: true,
            acting_username: user_5.username,
          }

      parsed = response.parsed_body
      expect(parsed.size).to eq(2)

      expect(parsed[0]["user"]["id"]).to eq(user_5.id)
      expect(parsed[0]["post_id"]).to eq(other_post.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(laugh.reaction.id)

      expect(parsed[1]["user"]["id"]).to eq(user_5.id)
      expect(parsed[1]["post_id"]).to eq(post_2.id)
      expect(parsed[1]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[1]["reaction"]["id"]).to eq(like.id)
    end

    it "also filter likes by id when including likes" do
      latest_like =
        Fabricate(
          :post_action,
          post: post_1,
          user: user_5,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
            include_likes: true,
            acting_username: user_5.username,
            before_like_id: latest_like.id,
          }

      parsed = response.parsed_body

      expect(parsed.size).to eq(1)
      expect(parsed[0]["user"]["id"]).to eq(user_5.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(like.id)
    end

    it "filters likes by username" do
      latest_like =
        Fabricate(
          :post_action,
          post: post_1,
          user: user_4,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )
      sign_in(user_1)

      get "/discourse-reactions/posts/reactions-received.json",
          params: {
            username: user_1.username,
            include_likes: true,
            acting_username: user_5.username,
          }

      parsed = response.parsed_body

      expect(parsed.size).to eq(1)
      expect(parsed[0]["user"]["id"]).to eq(user_5.id)
      expect(parsed[0]["post_id"]).to eq(post_2.id)
      expect(parsed[0]["post"]["user"]["id"]).to eq(user_1.id)
      expect(parsed[0]["reaction"]["id"]).to eq(like.id)
    end
  end

  describe "#post_reactions_users" do
    it "return reaction_users of post when theres no parameters" do
      get "/discourse-reactions/posts/#{post_2.id}/reactions-users.json"
      parsed = response.parsed_body

      expect(response.status).to eq(200)
      expect(parsed["reaction_users"][0]["users"][0]["username"]).to eq(user_5.username)
      expect(parsed["reaction_users"][0]["users"][0]["name"]).to eq(user_5.name)
      expect(parsed["reaction_users"][0]["users"][0]["avatar_template"]).to eq(
        user_5.avatar_template,
      )
    end

    it "return reaction_users of reaction when there are parameters" do
      get "/discourse-reactions/posts/#{post_2.id}/reactions-users.json?reaction_value=#{laughing_reaction.reaction_value}"
      parsed = response.parsed_body

      expect(response.status).to eq(200)
      expect(parsed["reaction_users"][0]["users"][0]["username"]).to eq(user_1.username)
      expect(parsed["reaction_users"][0]["users"][0]["name"]).to eq(user_1.name)
      expect(parsed["reaction_users"][0]["users"][0]["avatar_template"]).to eq(
        user_1.avatar_template,
      )
    end

    it "gives 404 ERROR when the post_id OR reaction_value is invalid" do
      get "/discourse-reactions/posts/1000000/reactions-users.json"
      expect(response.status).to eq(404)

      get "/discourse-reactions/posts/1000000/reactions-users.json?reaction_value=test"
      expect(response.status).to eq(404)
    end

    it "merges matching custom reaction into likes" do
      get "/discourse-reactions/posts/#{post_2.id}/reactions-users.json?reaction_value=#{DiscourseReactions::Reaction.main_reaction_id}"
      parsed = response.parsed_body
      like_count = parsed["reaction_users"][0]["count"].to_i
      expect(like_count).to eq(1)

      get "/discourse-reactions/posts/#{post_2.id}/reactions-users.json?reaction_value=laughing"
      parsed = response.parsed_body
      reaction_count = parsed["reaction_users"][0]["count"].to_i
      expect(reaction_count).to eq(2)

      SiteSetting.discourse_reactions_reaction_for_like = "laughing"

      get "/discourse-reactions/posts/#{post_2.id}/reactions-users.json?reaction_value=#{DiscourseReactions::Reaction.main_reaction_id}"
      parsed = response.parsed_body
      expect(parsed["reaction_users"][0]["count"]).to eq(like_count + reaction_count)
    end

    it "does not show reaction_users on PMs without permission" do
      get "/discourse-reactions/posts/#{private_post.id}/reactions-users.json"
      expect(response.status).to eq(403)
    end

    it "shows reaction_users on PMs with permission" do
      sign_in(user_2)
      get "/discourse-reactions/posts/#{private_post.id}/reactions-users.json"
      expect(response.status).to eq(200)
    end

    it "does not double up reactions which also count as likes if the reaction is no longer enabled" do
      post_for_enabled_reactions = Fabricate(:post, user: user_2)
      new_reaction_1 =
        Fabricate(:reaction, post: post_for_enabled_reactions, reaction_value: "laughing")
      new_reaction_user_1 =
        Fabricate(
          :reaction_user,
          user: user_5,
          reaction: new_reaction_1,
          post: post_for_enabled_reactions,
        )
      new_like_1 =
        Fabricate(
          :post_action,
          post: post_for_enabled_reactions,
          user: user_4,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )

      get "/discourse-reactions/posts/#{post_for_enabled_reactions.id}/reactions-users.json"
      parsed = response.parsed_body

      expect(response.status).to eq(200)
      expect(
        parsed["reaction_users"].find { |reaction| reaction["id"] == "laughing" }["count"],
      ).to eq(1)
      expect(parsed["reaction_users"].find { |reaction| reaction["id"] == "heart" }["count"]).to eq(
        1,
      )

      SiteSetting.discourse_reactions_enabled_reactions = "+1"

      get "/discourse-reactions/posts/#{post_for_enabled_reactions.id}/reactions-users.json"
      parsed = response.parsed_body

      expect(response.status).to eq(200)
      expect(
        parsed["reaction_users"].find { |reaction| reaction["id"] == "laughing" }["count"],
      ).to eq(1)
      expect(parsed["reaction_users"].find { |reaction| reaction["id"] == "heart" }["count"]).to eq(
        1,
      )
    end
  end

  describe "positive notifications" do
    before { PostActionNotifier.enable }

    it "creates notification when first like" do
      sign_in(user_1)
      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/heart/toggle.json"
      end.to change { Notification.count }.by(1).and change { PostAction.count }.by(1)

      expect(PostAction.last.post_action_type_id).to eq(PostActionType::LIKE_POST_ACTION_ID)

      expect do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/heart/toggle.json"
      end.to change { Notification.count }.by(-1).and change { PostAction.count }.by(-1)
    end
  end

  describe "reaction notifications" do
    it "calls ReactinNotification service" do
      sign_in(user_1)
      DiscourseReactions::ReactionNotification.any_instance.expects(:create).once
      DiscourseReactions::ReactionNotification.any_instance.expects(:delete).once
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/cry/toggle.json"
    end
  end

  it "allows to delete reaction only in undo action window frame" do
    SiteSetting.post_undo_action_window_mins = 10
    sign_in(user_1)
    expect do
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
    end.to change { DiscourseReactions::Reaction.count }.by(1).and change {
            DiscourseReactions::ReactionUser.count
          }.by(1)

    expect do
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
    end.to change { DiscourseReactions::Reaction.count }.by(-1).and change {
            DiscourseReactions::ReactionUser.count
          }.by(-1)

    expect do
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
    end.to change { DiscourseReactions::Reaction.count }.by(1).and change {
            DiscourseReactions::ReactionUser.count
          }.by(1)

    freeze_time(Time.zone.now + 11.minutes)
    expect do
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/hugs/toggle.json"
    end.to not_change { DiscourseReactions::Reaction.count }.and not_change {
            DiscourseReactions::ReactionUser.count
          }

    expect(response.status).to eq(403)
  end
end
