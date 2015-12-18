require 'rails_helper'
require_dependency 'current_user'

describe CurrentUser do
  it "allows us to lookup a user from our environment" do
    user = Fabricate(:user, auth_token: EmailToken.generate_token, active: true)
    EmailToken.confirm(user.auth_token)

    env = Rack::MockRequest.env_for("/test", "HTTP_COOKIE" => "_t=#{user.auth_token};")
    expect(CurrentUser.lookup_from_env(env)).to eq(user)
  end

end
