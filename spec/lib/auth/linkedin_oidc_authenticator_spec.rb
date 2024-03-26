# frozen_string_literal: true

RSpec.describe Auth::LinkedInOidcAuthenticator do
  subject(:authenticator) { Auth::LinkedInOidcAuthenticator.new }

  let(:hash) do
    {
      provider: "linkedin",
      extra: {
      },
      info: {
        email: "bob@bob.com",
        first_name: "Bob",
        last_name: "Smith",
      },
      uid: "100",
    }
  end

  describe "revoke" do
    fab!(:user)

    context "when there's no record for the user" do
      it { expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound) }
    end

    context "when user has a valid record" do
      before do
        UserAssociatedAccount.create!(
          provider_name: "linkedin",
          user_id: user.id,
          provider_uid: 100,
          info: {
            email: "bob@bob.com",
          },
        )
      end

      it "revokes correctly" do
        expect(authenticator.description_for_user(user)).to eq("bob@bob.com")
        expect(authenticator.can_revoke?).to eq(true)
        expect(authenticator.revoke(user)).to eq(true)
        expect(authenticator.description_for_user(user)).to eq("")
      end
    end
  end
end
