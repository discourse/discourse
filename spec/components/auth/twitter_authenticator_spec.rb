require 'rails_helper'

describe Auth::TwitterAuthenticator do

  it "takes over account if email is supplied" do
    auth = Auth::TwitterAuthenticator.new

    user = Fabricate(:user)

    auth_token = {
      info: {
        "email" => user.email,
        "username" => "test",
        "name" => "test",
        "nickname" => "minion",
      },
      "uid" => "123"
    }

    result = auth.after_authenticate(auth_token)

    expect(result.user.id).to eq(user.id)

    info = TwitterUserInfo.find_by(user_id: user.id)
    expect(info.email).to eq(user.email)
  end

end
