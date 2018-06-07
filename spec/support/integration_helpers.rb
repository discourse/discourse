module IntegrationHelpers
  def create_user
    get "/u/hp.json"

    expect(response.status).to eq(200)

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

    expect(response.status).to eq(200)

    body = JSON.parse(response.body)
    User.find(body["user_id"])
  end

  def sign_in(user)
    get "/session/#{user.username}/become"
    user
  end
end
