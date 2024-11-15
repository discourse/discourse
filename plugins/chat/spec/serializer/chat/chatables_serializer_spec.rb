# frozen_string_literal: true

describe Chat::ChatablesSerializer do
  context "with status" do
    fab!(:user_1) { Fabricate(:user) }

    before do
      SiteSetting.enable_user_status = true
      user_1.set_status!("test", ":cat:")
    end

    it "includes status" do
      serializer =
        described_class.new(
          OpenStruct.new({ users: [user_1] }),
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        )

      expect(serializer.users[0]["model"][:status]).to be_present
    end

    context "with hidden profile" do
      before { user_1.user_option.update!(hide_profile: true) }

      it "doesn’t include status" do
        serializer =
          described_class.new(
            OpenStruct.new({ users: [user_1] }),
            scope: Guardian.new(Fabricate(:user)),
            root: false,
          )

        expect(serializer.users[0]["model"][:status]).to be_blank
      end
    end
  end
end
