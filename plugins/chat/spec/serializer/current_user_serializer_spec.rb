# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:current_user) { Fabricate(:user) }

  let(:serializer) do
    described_class.new(current_user, scope: Guardian.new(current_user), root: false)
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    current_user.user_option.update(chat_enabled: true)
  end

  describe "#chat_separate_sidebar_mode" do
    it "is present" do
      expect(serializer.as_json[:user_option][:chat_separate_sidebar_mode]).to eq("default")
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
      before { current_user.user_option.update!(chat_quick_reactions_custom: "tada|smiley") }

      it "is present" do
        expect(serializer.as_json[:user_option][:chat_quick_reactions_custom]).to eq("tada|smiley")
      end
    end
  end

  describe "#chat_drafts" do
    context "when user can't chat" do
      before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff] }

      it "is not present" do
        expect(serializer.as_json[:chat_drafts]).to be_blank
      end
    end

    it "is ordered by most recent drafts" do
      Fabricate(:chat_draft, user: current_user, value: "second draft")
      Fabricate(:chat_draft, user: current_user, value: "first draft")

      values =
        serializer.as_json[:chat_drafts].map { |draft| MultiJson.load(draft[:data])["value"] }
      expect(values).to eq(["first draft", "second draft"])
    end

    it "limits the numbers of drafts" do
      21.times { Fabricate(:chat_draft, user: current_user) }

      expect(serializer.as_json[:chat_drafts].length).to eq(20)
    end
  end
end
