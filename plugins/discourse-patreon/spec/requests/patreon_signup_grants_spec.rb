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
end
