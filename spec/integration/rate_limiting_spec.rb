# encoding: UTF-8

require 'rails_helper'

describe 'admin rate limit' do

  before do
    RateLimiter.enable
  end

  after do
    RateLimiter.disable
  end

  it 'can cleanly limit requests' do
    #request.set_header("action_dispatch.show_exceptions", true)

    admin = Fabricate(:admin)
    api_key = Fabricate(:api_key, key: SecureRandom.hex, user: admin)

    global_setting :max_admin_api_reqs_per_key_per_minute, 1

    get '/admin/api/keys.json', params: {
      api_key: api_key.key,
      api_username: admin.username
    }

    expect(response.status).to eq(200)

    get '/admin/api/keys.json', params: {
      api_key: api_key.key,
      api_username: admin.username
    }

    expect(response.status).to eq(429)
  end
end
