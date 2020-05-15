# frozen_string_literal: true

require 'rails_helper'

describe 'api keys' do
  let(:user) { Fabricate(:user) }
  let(:api_key) { ApiKey.create!(user_id: user.id, created_by_id: Discourse.system_user) }

  it 'works in headers' do
    get '/session/current.json', headers: {
      HTTP_API_KEY: api_key.key
    }
    expect(response.status).to eq(200)
    expect(response.parsed_body["current_user"]["username"]).to eq(user.username)
  end

  it 'does not work in parameters' do
    get '/session/current.json', params: {
      api_key: api_key.key
    }
    expect(response.status).to eq(404)
  end

  it 'allows parameters on ics routes' do
    get "/u/#{user.username}/bookmarks.ics?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(200)

    # Confirm not for JSON
    get "/u/#{user.username}/bookmarks.json?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(403)
  end

  it 'allows parameters for handle mail' do
    admin_api_key = ApiKey.create!(user: Fabricate(:admin), created_by_id: Discourse.system_user)

    post "/admin/email/handle_mail.json?api_key=#{admin_api_key.key}", params: { email: "blah" }
    expect(response.status).to eq(200)
  end

  it 'allows parameters for rss feeds' do
    SiteSetting.login_required = true

    get "/latest.rss?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(200)

    # Confirm not allowed for json
    get "/latest.json?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(302)
  end

end

describe 'user api keys' do
  let(:user) { Fabricate(:user) }
  let(:user_api_key) { Fabricate(:readonly_user_api_key, user: user) }

  it 'updates last used time on use' do
    freeze_time

    user_api_key.update_columns(last_used_at: 7.days.ago)

    get '/session/current.json', headers: {
      HTTP_USER_API_KEY: user_api_key.key,
    }

    expect(user_api_key.reload.last_used_at).to eq_time(Time.zone.now)
  end

  it 'allows parameters on ics routes' do
    get "/u/#{user.username}/bookmarks.ics?user_api_key=#{user_api_key.key}"
    expect(response.status).to eq(200)

    # Confirm not for JSON
    get "/u/#{user.username}/bookmarks.json?user_api_key=#{user_api_key.key}"
    expect(response.status).to eq(403)
  end

  it 'allows parameters for rss feeds' do
    SiteSetting.login_required = true

    get "/latest.rss?user_api_key=#{user_api_key.key}"
    expect(response.status).to eq(200)

    # Confirm not allowed for json
    get "/latest.json?user_api_key=#{user_api_key.key}"
    expect(response.status).to eq(302)
  end

end
