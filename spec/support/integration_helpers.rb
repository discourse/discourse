module IntegrationHelpers
  def create_user
    get "/u/hp.json"

    expect(response).to be_success

    body = JSON.parse(response.body)
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

    expect(response).to be_success

    body = JSON.parse(response.body)
    User.find(body["user_id"])
  end

  def sign_in(user)
    password = 'somecomplicatedpassword'
    user.update!(password: password)
    Fabricate(:email_token, confirmed: true, user: user)
    post "/session.json", params: { login: user.username, password: password }
    expect(response).to be_success
  end
end
