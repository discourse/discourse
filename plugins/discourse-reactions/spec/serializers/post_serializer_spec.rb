# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"
require_relative "../fabricators/reaction_user_fabricator.rb"

describe PostSerializer do
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:user_4, :user)
  fab!(:post_1) { Fabricate(:post, user: user_1) }
  let(:reaction_otter) { Fabricate(:reaction, reaction_value: "otter", post: post_1) }
  let(:reaction_plus_1) { Fabricate(:reaction, reaction_value: "+1", post: post_1) }
  let(:reaction_user_1) do
    Fabricate(:reaction_user, reaction: reaction_otter, user: user_1, post: post_1)
  end
  let(:reaction_user_2) do
    Fabricate(:reaction_user, reaction: reaction_otter, user: user_2, post: post_1)
  end
  let(:reaction_user_3) do
    Fabricate(
      :reaction_user,
      reaction: reaction_plus_1,
      user: user_3,
      post: post_1,
      created_at: 20.minutes.ago,
    )
  end
  fab!(:like) do
    Fabricate(
      :post_action,
      post: post_1,
      user: user_4,
      post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
    )
  end

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.post_undo_action_window_mins = 10
    SiteSetting.discourse_reactions_enabled_reactions = "otter|+1"
    SiteSetting.discourse_reactions_like_icon = "heart"

    reaction_user_1 && reaction_user_2 && reaction_user_3 && like

    post_1.post_actions_with_reaction_users =
      DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
        [post_1.id],
      )[
        post_1.id
      ]
  end

  it "renders custom reactions which should be sorted by count" do
    json = PostSerializer.new(post_1, scope: Guardian.new(user_1), root: false).as_json

    expect(json[:reactions]).to eq(
      [
        { id: "otter", type: :emoji, count: 2 },
        { id: "+1", type: :emoji, count: 1 },
        { id: "heart", type: :emoji, count: 1 },
      ],
    )

    expect(json[:current_user_reaction]).to eq({ type: :emoji, id: "otter", can_undo: true })

    json = PostSerializer.new(post_1, scope: Guardian.new(user_2), root: false).as_json

    expect(json[:reaction_users_count]).to eq(4)
  end

  it "renders custom reactions sorted alphabetically if count is equal" do
    json = PostSerializer.new(post_1, scope: Guardian.new(user_1), root: false).as_json

    expect(json[:reactions]).to eq(
      [
        { id: "otter", type: :emoji, count: 2 },
        { id: "+1", type: :emoji, count: 1 },
        { id: "heart", type: :emoji, count: 1 },
      ],
    )
  end

  it "does not double up reactions which also count as likes if the reaction is no longer enabled" do
    SiteSetting.discourse_reactions_enabled_reactions = "+1"
    json = PostSerializer.new(post_1, scope: Guardian.new(user_1), root: false).as_json

    expect(json[:reactions]).to eq(
      [
        { id: "otter", type: :emoji, count: 2 },
        { id: "+1", type: :emoji, count: 1 },
        { id: "heart", type: :emoji, count: 1 },
      ],
    )
  end

  describe "custom emojis" do
    fab!(:custom_emoji) do
      CustomEmoji.create!(upload: Fabricate(:image_upload), name: "some_custom_emoji")
    end

    fab!(:custom_emoji_reaction) do
      Fabricate(:reaction, reaction_value: custom_emoji.name, post: post_1)
    end

    fab!(:user_5, :user)

    fab!(:custom_reaction_user) do
      Fabricate(:reaction_user, reaction: custom_emoji_reaction, user: user_5, post: post_1)
    end

    before do
      SiteSetting.discourse_reactions_enabled_reactions += "|#{custom_emoji.name}"
      Emoji.clear_cache
    end

    it "renders the right custom reactions including custom emoji" do
      json = PostSerializer.new(post_1, scope: Guardian.new(user_5), root: false).as_json

      expect(json[:reactions]).to eq(
        [
          { id: "otter", type: :emoji, count: 2 },
          { id: "+1", type: :emoji, count: 1 },
          { id: "heart", type: :emoji, count: 1 },
          { id: "some_custom_emoji", type: :emoji, count: 1 },
        ],
      )
    end

    it "renders custom reactions correctly when custom emoji is destroyed" do
      custom_emoji.destroy!
      Emoji.clear_cache

      json = PostSerializer.new(post_1.reload, scope: Guardian.new(user_5), root: false).as_json

      expect(json[:reactions]).to eq(
        [
          { id: "otter", type: :emoji, count: 2 },
          { id: "+1", type: :emoji, count: 1 },
          { id: "heart", type: :emoji, count: 1 },
        ],
      )
    end
  end

  context "when disabled" do
    it "is not extending post serializer when plugin is disabled" do
      SiteSetting.discourse_reactions_enabled = false
      json = PostSerializer.new(post_1, scope: Guardian.new(user_1), root: false).as_json
      expect(json[:reactions]).to be nil
    end
  end

  describe "changing discourse_reactions_like_icon" do
    before { SiteSetting.discourse_reactions_reaction_for_like = "otter" }

    it "merges the newly matching custom reaction into likes" do
      json = PostSerializer.new(post_1, scope: Guardian.new(user_1), root: false).as_json

      expect(json[:reactions]).to eq(
        [{ id: "otter", type: :emoji, count: 3 }, { id: "+1", type: :emoji, count: 1 }],
      )
    end
  end
end
