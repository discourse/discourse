# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:user)

  let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(serializer.as_json[:user_option][:chat_separate_sidebar_mode]).to eq("default")
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
