require 'rails_helper'

describe 'user api keys integration' do

  let(:user_api_key) { Fabricate(:readonly_user_api_key) }

  it 'updates last used time on use' do
    user_api_key.update_columns(last_used_at: 7.days.ago)

    freeze_time
    get '/session/current.json', headers: {
      HTTP_USER_API_KEY: user_api_key.key,
    }
    expect(user_api_key.reload.last_used_at).to eq(Time.zone.now)
  end
end
