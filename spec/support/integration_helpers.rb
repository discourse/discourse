module IntegrationHelpers
  def sign_in(user)
    password = 'somecomplicatedpassword'
    user.update!(password: password)
    Fabricate(:email_token, confirmed: true, user: user)
    post "/session.json", { login: user.username, password: password }
    expect(response).to be_success
  end
end
