# frozen_string_literal: true

RSpec.describe "Pending push subscription registration", type: :request do
  self.use_transactional_tests = false

  let!(:master) { Fabricate(:user) }
  let!(:shadow) { Fabricate(:user) }

  before { AnonymousUser.create!(user: shadow, master_user: master, active: true) }

  after do
    shadow.destroy!
    master.destroy!
    UserAuthTokenLog.where(user_id: [master.id, shadow.id]).delete_all
  end

  it "rejects a request authenticated as a shadow before family-wide revocation committed" do
    token = UserAuthToken.generate!(user_id: shadow.id)
    cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: shadow.id)
    path = "/push_notifications/subscribe.json"
    env = create_request_env(path: path).merge("HTTP_COOKIE" => "_t=#{cookie}")
    provider = Auth::DefaultCurrentUserProvider.new(env)
    expect(provider.current_user).to eq(shadow)
    expect(provider.authenticated_session_user).to eq(shadow)

    master_id = master.id
    Thread
      .new { User.connection_pool.with_connection { User.find(master_id).revoke_family_sessions! } }
      .value

    # Resume the request with the principal and token already cached by middleware.
    post path,
         headers: {
           "HTTP_COOKIE" => "_t=#{cookie}",
         },
         env:
           env.slice(
             Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY,
             Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY,
           ),
         params: {
           subscription: {
             endpoint: "https://fcm.googleapis.com/fcm/send/1",
             keys: {
               p256dh: "256dh",
               auth: "auth",
             },
           },
         }

    expect(response.status).to eq(403)
    expect(response.parsed_body["error_type"]).to eq("invalid_access")
    expect(PushSubscription.where(user_id: [master.id, shadow.id])).to be_empty
  end
end
