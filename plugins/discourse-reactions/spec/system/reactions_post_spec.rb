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

  context "when discourse_reactions_experimental_allow_any_emoji is enabled" do
    before { SiteSetting.discourse_reactions_experimental_allow_any_emoji = true }

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
