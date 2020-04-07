# frozen_string_literal: true

require 'rails_helper'

describe 'user api keys integration' do
  it 'updates last used time on use' do
    freeze_time

    user_api_key = Fabricate(:readonly_user_api_key)
    user_api_key.update_columns(last_used_at: 7.days.ago)

    get '/session/current.json', headers: {
      HTTP_USER_API_KEY: user_api_key.key,
    }

    expect(user_api_key.reload.last_used_at).to eq_time(Time.zone.now)
  end
end
