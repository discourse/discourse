# frozen_string_literal: true

describe "Reactions | Post reactions" do
  fab!(:current_user, :user)
  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic:) }
  fab!(:post_2) { Fabricate(:post, topic:) }

  let(:reactions_button) do
    PageObjects::Components::PostReactionsButton.new("#post_#{post_2.post_number}")
  end
  let(:reactions_list) do
    PageObjects::Components::PostReactionsList.new("#post_#{post_2.post_number}")
  end

  before do
    SiteSetting.discourse_reactions_enabled = true
    sign_in(current_user)
  end

  context "when user has reacted but like_count is 0 and undo window passed" do
    fab!(:reaction) { Fabricate(:reaction, post: post_2) }
    fab!(:reaction_user) { Fabricate(:reaction_user, reaction:, user: current_user, post: post_2) }
    fab!(:post_action) do
      Fabricate(
        :post_action,
        user: current_user,
        post: post_2,
        post_action_type_id: PostActionType.types[:like],
        created_at: 1.day.ago,
      )
    end

    before do
      SiteSetting.post_undo_action_window_mins = 10
      post_2.update_column(:like_count, 0)
    end

    it "displays the user's reaction" do
      visit post_2.url
      expect(reactions_list).to have_reaction(reaction.reaction_value)
    end
  end

  it "can do a basic post reaction with a default reaction" do
    visit post_2.url
    reactions_button.hover_like_button(post_2.id)
    expect(reactions_button).to have_expanded_reactions_picker(post_2.id)
    reactions_button.pick_reaction("laughing")
    expect(reactions_list).to have_reaction("laughing")
  end

  it "does not show emoji_deny_list emojis for post reactions" do
    SiteSetting.emoji_deny_list = "middle_finger"
    visit post_2.url
    reactions_button.hover_like_button(post_2.id)
    expect(reactions_button).to have_expanded_reactions_picker(post_2.id)
    expect(reactions_button).to have_no_emoji("middle_finger")
  end

  it "only shows enabled reaction emojis" do
    SiteSetting.discourse_reactions_enabled_reactions = "clap|hugs"
    visit post_2.url
    reactions_button.hover_like_button(post_2.id)
    expect(reactions_button).to have_expanded_reactions_picker(post_2.id)
    expect(reactions_button).to have_no_emoji("open_mouth")
    expect(reactions_button).to have_emoji("clap")
    expect(reactions_button).to have_emoji("hugs")
  end

  context "when discourse_reactions_allow_any_emoji is enabled" do
    before { SiteSetting.discourse_reactions_allow_any_emoji = true }

    it "allows selecting any emoji for a post reaction" do
      visit post_2.url
      reactions_button.hover_like_button(post_2.id)
      expect(reactions_button).to have_expanded_reactions_picker(post_2.id)
      reactions_button.pick_any_reaction("yawning_face")
      expect(reactions_list).to have_reaction("yawning_face")
    end

    it "does not allow selecting any emoji_deny_list emojis for post reactions" do
      SiteSetting.emoji_deny_list = "middle_finger"
      visit post_2.url
      reactions_button.hover_like_button(post_2.id)
      expect(reactions_button).to have_expanded_reactions_picker(post_2.id)
      reactions_button.open_emoji_picker
      reactions_button.filter_emoji_picker("middle_finger")
      expect(reactions_button).to have_no_emoji_picker_emoji("middle_finger")
    end
  end
end
