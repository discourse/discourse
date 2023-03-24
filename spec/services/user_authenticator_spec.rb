# frozen_string_literal: true

RSpec.describe UserAuthenticator do
  def github_auth(email_valid)
    {
      email: "user53@discourse.org",
      username: "joedoe546",
      email_valid: email_valid,
      omit_username: nil,
      name: "Joe Doe 546",
      authenticator_name: "github",
      extra_data: {
        provider: "github",
        uid: "100",
      },
      skip_email_validation: false,
    }
  end

  before { SiteSetting.enable_github_logins = true }

  describe "#start" do
    describe "without authentication session" do
      it "should apply the right user attributes" do
        user = User.new
        UserAuthenticator.new(user, {}).start

        expect(user.password_required?).to eq(true)
      end

      it "allows password requirement to be skipped" do
        user = User.new
        UserAuthenticator.new(user, {}, require_password: false).start

        expect(user.password_required?).to eq(false)
      end
    end
  end

  describe "#finish" do
    fab!(:group) { Fabricate(:group, automatic_membership_email_domains: "discourse.org") }

    it "confirms email and adds the user to appropriate groups based on email" do
      user = Fabricate(:user, email: "user53@discourse.org")
      expect(group.usernames).not_to include(user.username)

      authentication = github_auth(true)

      UserAuthenticator.new(user, { authentication: authentication }).finish
      expect(user.email_confirmed?).to be_truthy
      expect(group.usernames).to include(user.username)
    end

    it "doesn't confirm email if email is invalid" do
      user = Fabricate(:user, email: "user53@discourse.org")

      authentication = github_auth(false)

      UserAuthenticator.new(user, { authentication: authentication }).finish
      expect(user.email_confirmed?).to be_falsey
      expect(group.usernames).not_to include(user.username)
    end

    it "doesn't confirm email if it was changed" do
      user = Fabricate(:user, email: "changed@discourse.org")

      authentication = github_auth(true)

      UserAuthenticator.new(user, { authentication: authentication }).finish
      expect(user.email_confirmed?).to be_falsey
      expect(group.usernames).not_to include(user.username)
    end

    it "clears the authentication info from the session" do
      user = Fabricate(:user, email: "user53@discourse.org")
      session = { authentication: github_auth(true) }

      UserAuthenticator.new(user, session).finish
      expect(user.email_confirmed?).to be_truthy

      expect(session[:authentication]).to eq(nil)
    end

    it "raises an error for non-boolean values" do
      user = Fabricate(:user, email: "user53@discourse.org")
      session = { authentication: github_auth("string") }

      expect do UserAuthenticator.new(user, session).finish end.to raise_error ArgumentError
    end
  end
end
