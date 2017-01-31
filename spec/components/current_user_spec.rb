require 'rails_helper'
require_dependency 'current_user'

describe CurrentUser do
  it "allows us to lookup a user from our environment" do
    user = Fabricate(:user, active: true)
    token = UserAuthToken.generate!(user_id: user.id)

    env = Rack::MockRequest.env_for("/test", "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token};")
    expect(CurrentUser.lookup_from_env(env)).to eq(user)
  end

end
