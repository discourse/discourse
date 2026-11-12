# frozen_string_literal: true

RSpec.describe "Patreon group grants during signup" do
  fab!(:group)
  fab!(:other_group, :group)

  let(:patreon_id) { "493290423324" }
  let(:patron_email) { "real-patron@example.com" }

  before do
    SiteSetting.patreon_enabled = true
    SiteSetting.allow_new_registrations = true
    UsersController.any_instance.stubs(:honeypot_value).returns(nil)
    UsersController.any_instance.stubs(:challenge_value).returns(nil)

    Patreon.set("users", { patreon_id => patron_email })
    Patreon.set("reward-users", { "0" => [patreon_id], "4589" => [patreon_id], "9999" => [] })
    Patreon.set("filters", { group.id.to_s => ["4589"], other_group.id.to_s => ["9999"] })
  end

  def signup(email)
    post "/u.json",
         params: {
           name: "Mallory",
           username: "mallory",
           password: "strongpassword123",
           email: email,
         }
  end

  it "does not grant patron groups to a new account with an unverified patron email" do
    expect { signup(patron_email) }.to change { User.count }.by(1)
    expect(response.status).to eq(200)

    user = User.find_by(username: "mallory")
    expect(user).to be_present
    expect(user.active).to eq(false)

    expect(group.users).not_to include(user)
    expect(user.custom_fields["patreon_id"]).to be_blank
  end

  it "grants only currently eligible patron groups once the signup email is confirmed" do
    signup(patron_email)
    user = User.find_by(username: "mallory")

    email_token = user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
    EmailToken.confirm(email_token.token, scope: EmailToken.scopes[:signup])

    expect(group.users.reload).to include(user)
    expect(other_group.users.reload).not_to include(user)
    expect(user.reload.custom_fields["patreon_id"]).to eq(patreon_id)
  end

  it "does not retain entitlements when the unconfirmed patron email is swapped before confirmation" do
    signup(patron_email)
    user = User.find_by(username: "mallory")

    email_token =
      user.email_tokens.create!(email: "mallory@example.com", scope: EmailToken.scopes[:signup])
    EmailToken.confirm(email_token.token, scope: EmailToken.scopes[:signup])

    user.reload
    expect(user.email).to eq("mallory@example.com")
    expect(group.users.reload).not_to include(user)
    expect(user.custom_fields["patreon_id"]).to be_blank
  end

  context "with DiscourseConnect" do
    before do
      SiteSetting.discourse_connect_url = "https://sso.example.com"
      SiteSetting.discourse_connect_secret = "discourse-connect-secret"
      SiteSetting.enable_discourse_connect = true
    end

    def discourse_connect_login(require_activation: false)
      discourse_connect = DiscourseConnect.new(server_session:)
      discourse_connect.nonce = SecureRandom.hex
      discourse_connect.register_nonce("/")

      payload = DiscourseConnectBase.new
      payload.nonce = discourse_connect.nonce
      payload.sso_secret = SiteSetting.discourse_connect_secret
      payload.external_id = "patron"
      payload.email = patron_email
      payload.username = "patron"
      payload.require_activation = require_activation

      get "/session/sso_login", params: Rack::Utils.parse_query(payload.payload)
    end

    it "grants patron groups during trusted login" do
      discourse_connect_login

      expect(response.status).to eq(302)
      user = User.find_by!(username: "patron")
      expect(session[:current_user_id]).to eq(user.id)
      expect(user.custom_fields["patreon_id"]).to eq(patreon_id)
      expect(group.users).to contain_exactly(user)
      expect(other_group.users).to be_empty
    end

    it "defers grants until confirmation when the provider requires activation" do
      discourse_connect_login(require_activation: true)

      expect(response.status).to eq(302)
      user = User.find_by!(username: "patron")
      expect(session[:current_user_id]).to be_nil
      expect(user.active?).to eq(false)
      expect(user.custom_fields["patreon_id"]).to be_blank
      expect(group.users).to be_empty

      user.activate

      expect(user.reload.custom_fields["patreon_id"]).to eq(patreon_id)
      expect(group.users).to contain_exactly(user)
    end
  end

  it "leaves inactive accounts unbound when a login event is emitted" do
    signup(patron_email)
    user = User.find_by!(username: "mallory")

    DiscourseEvent.trigger(:user_logged_in, user)

    expect(user.reload.custom_fields["patreon_id"]).to be_blank
    expect(group.users).to be_empty
  end

  it "preserves an existing owner's binding when another account confirms the patron email" do
    owner = Fabricate(:user)
    owner.custom_fields["patreon_id"] = patreon_id
    owner.save_custom_fields
    Patreon::Patron.sync_groups_by(patreon_id:)
    signup(patron_email)
    user = User.find_by!(username: "mallory")

    user.activate

    expect(user.reload.custom_fields["patreon_id"]).to be_blank
    expect(owner.reload.custom_fields["patreon_id"]).to eq(patreon_id)
    expect(group.users).to contain_exactly(owner)
  end

  it "prefers a Patreon associated account when another account confirms the patron email" do
    owner = Fabricate(:user)
    Fabricate(
      :user_associated_account,
      user: owner,
      provider_name: "patreon",
      provider_uid: patreon_id,
    )
    signup(patron_email)
    user = User.find_by!(username: "mallory")

    user.activate

    expect(user.reload.custom_fields["patreon_id"]).to be_blank
    expect(owner.reload.custom_fields["patreon_id"]).to eq(patreon_id)
    expect(group.users).to contain_exactly(owner)
  end

  it "allows login even when the cached patron data is malformed" do
    user = Fabricate(:user, email: patron_email)
    Patreon.set("users", {})
    user.activate
    Patreon.set("users", [])

    post "/session.json", params: { login: user.username, password: "myawesomepassword" }

    expect(response.status).to eq(200)
    expect(response.parsed_body["error"]).to be_nil
    expect(session[:current_user_id]).to eq(user.id)
    expect(user.reload.custom_fields["patreon_id"]).to be_blank
    expect(group.users).to be_empty
  end
end
