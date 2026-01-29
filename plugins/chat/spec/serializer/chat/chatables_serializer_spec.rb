# frozen_string_literal: true

describe Chat::ChatablesSerializer do
  fab!(:user_1, :user)

  let(:scope) { Guardian.new(Fabricate(:user)) }

  describe "match_quality" do
    it "includes match_quality from records that respond to it" do
      user_1.define_singleton_method(:match_quality) { Chat::ChannelFetcher::MATCH_QUALITY_EXACT }

      serializer =
        described_class.new(OpenStruct.new(users: [user_1], memberships: []), scope:, root: false)

      expect(serializer.users[0]["match_quality"]).to eq(Chat::ChannelFetcher::MATCH_QUALITY_EXACT)
    end

    it "defaults to MATCH_QUALITY_PARTIAL when record doesn't respond to match_quality" do
      serializer =
        described_class.new(OpenStruct.new(users: [user_1], memberships: []), scope:, root: false)

      expect(serializer.users[0]["match_quality"]).to eq(
        Chat::ChannelFetcher::MATCH_QUALITY_PARTIAL,
      )
    end
  end

  describe "user status" do
    before do
      SiteSetting.enable_user_status = true
      user_1.set_status!("test", ":cat:")
    end

    it "includes status" do
      serializer =
        described_class.new(OpenStruct.new(users: [user_1], memberships: []), scope:, root: false)

      expect(serializer.users[0]["model"][:status]).to be_present
    end

    context "with hidden profile" do
      before { user_1.user_option.update!(hide_profile: true) }

      it "doesn't include status" do
        serializer =
          described_class.new(OpenStruct.new(users: [user_1], memberships: []), scope:, root: false)

        expect(serializer.users[0]["model"][:status]).to be_blank
      end
    end
  end
end
