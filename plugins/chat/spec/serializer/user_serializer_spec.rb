# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:user)

  let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(serializer.as_json[:user_option][:chat_separate_sidebar_mode]).to eq("default")
    end
  end

  describe "#can_chat" do
    fab!(:moderator)
    fab!(:other_user, :user)

    before { SiteSetting.chat_enabled = true }

    def serialize(viewer)
      described_class.new(user, scope: viewer.guardian, root: false).as_json
    end

    it "serializes whether the viewed user can chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]

      expect(serialize(moderator)[:can_chat]).to eq(true)

      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]

      expect(serialize(moderator)[:can_chat]).to eq(false)
    end

    it "is only included for users who can edit the viewed user" do
      expect(serialize(other_user)).not_to have_key(:can_chat)
    end
  end

  describe "#chat_channel_list_preferences" do
    it "includes default values" do
      expect(serializer.as_json[:user_option]).to include(
        chat_channel_list_filter: "all",
        chat_channel_list_sort: "alphabetical",
      )
    end

    it "includes changed values" do
      user.user_option.update!(
        chat_channel_list_filter: "mentions",
        chat_channel_list_sort: "priority",
      )

      expect(serializer.as_json[:user_option]).to include(
        chat_channel_list_filter: "mentions",
        chat_channel_list_sort: "priority",
      )
    end
  end

  describe "#chat_quick_reaction_type" do
    it "is present with default enum string" do
      expect(serializer.as_json[:user_option][:chat_quick_reaction_type]).to eq("frequent")
    end
  end

  describe "#chat_quick_reactions_custom" do
    it "is present with default enum string" do
      expect(serializer.as_json[:user_option][:chat_quick_reactions_custom]).to eq(nil)
    end

    context "with custom quick reactions" do
      before { user.user_option.update!(chat_quick_reactions_custom: "tada|smiley") }

      it "is present" do
        expect(serializer.as_json[:user_option][:chat_quick_reactions_custom]).to eq("tada|smiley")
      end
    end
  end
end
