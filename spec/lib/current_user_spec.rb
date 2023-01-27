# frozen_string_literal: true

RSpec.describe CurrentUser do
  it "allows us to lookup a user from our environment" do
    user = Fabricate(:user, active: true)
    token = UserAuthToken.generate!(user_id: user.id)

    cookie =
      create_auth_cookie(
        token: token.unhashed_auth_token,
        user_id: user.id,
        trust_level: user.trust_level,
        issued_at: 5.minutes.ago,
      )

    env = create_request_env(path: "/test").merge("HTTP_COOKIE" => "_t=#{cookie};")
    expect(CurrentUser.lookup_from_env(env)).to eq(user)
  end
end
