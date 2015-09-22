require 'rails_helper'

RSpec.describe ManifestJsonController do
  context 'index' do
    it 'returns the right output' do
      title = 'MyApp'
      SiteSetting.title = title
      get :index
      expect(JSON.parse(response.body)["short_name"]).to eq(title)
    end

    it 'includes details for google cloud message' do
      get :index
      expect(JSON.parse(response.body)["gcm_sender_id"]).to eq(nil)

      SiteSetting.gcm_sender_id = "123456"
      get :index
      expect(JSON.parse(response.body)["gcm_sender_id"]).to eq(SiteSetting.gcm_sender_id)
      expect(JSON.parse(response.body)["gcm_user_visible_only"]).to eq(true)
    end
  end
end
