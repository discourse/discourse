require 'rails_helper'

describe Jobs::UpdateGravatar do

  it "picks gravatar if system avatar is picked and gravatar was just downloaded" do
    user = User.create!(username: "bob", name: "bob", email: "a@a.com")
    expect(user.uploaded_avatar_id).to eq(nil)
    expect(user.user_avatar.gravatar_upload_id).to eq(nil)

    png = Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==")
    url = "https://www.gravatar.com/avatar/d10ca8d11301c2f4993ac2279ce4b930.png?s=360&d=404"
    stub_request(:get, url).to_return(body: png)

    SiteSetting.automatically_download_gravatars = true

    user.refresh_avatar
    user.reload

    expect(user.uploaded_avatar_id).to eq(user.user_avatar.gravatar_upload_id)
  end

end
