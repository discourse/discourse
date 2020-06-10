# frozen_string_literal: true

module IntegrationHelpers
  def create_user
    get "/u/hp.json"

    expect(response.status).to eq(200)

    body = response.parsed_body
    honeypot = body["value"]
    challenge = body["challenge"]
    user = Fabricate.build(:user)

    post "/u.json", params: {
      username: user.username,
      email: user.email,
      password: 'asdasljdhaiosdjioaeiow',
      password_confirmation: honeypot,
      challenge: challenge.reverse
    }

    expect(response.status).to eq(200)

    body = response.parsed_body
    User.find(body["user_id"])
  end

  def sign_in(user)
    get "/session/#{user.encoded_username}/become"
    user
  end

  def sign_out
    delete "/session"
  end

  def read_secure_session
    SecureSession.new(session[:secure_session_id])
  end
end
