require 'spec_helper'

describe UserAvatarsController do

  context 'show' do
    it 'redirects to correct size for non local' do
      SiteSetting.avatar_sizes = "100|49"
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_access_key_id = "XXX"
      SiteSetting.s3_secret_access_key = "XXX"
      SiteSetting.s3_upload_bucket = "test"

      GlobalSetting.expects(:cdn_url).returns("http://awesome.com/boom")


      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get :show, size: 97, username: user.username, version: upload.id, hostname: 'default'

      # 98 is closese which is 49 * 2 for retina
      expect(response).to redirect_to("http://awesome.com/boom/user_avatar/default/#{user.username_lower}/98/#{upload.id}.png")
    end

    it 'serves image even if size missing and its in local mode' do
      SiteSetting.avatar_sizes = "50"

      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      get :show, size: 51, username: user.username, version: upload.id, hostname: 'default'
      expect(response).to be_success
    end
  end
end
