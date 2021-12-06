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
    expect(response.status).to eq(403)
  end

  context "with a plugin registered filter" do
    before do
      plugin = Plugin::Instance.new
      plugin.add_api_parameter_route methods: [:get], actions: ["session#current"]
    end

    it 'allows parameter access to the registered route' do
      get '/session/current.json', params: {
        api_key: api_key.key
      }
      expect(response.status).to eq(200)
    end
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
    expect(response.status).to eq(403)
  end

  it "can restrict scopes by parameters" do
    admin = Fabricate(:admin)

    calendar_key = Fabricate(:bookmarks_calendar_user_api_key, user: admin)

    get "/u/#{user.username}/bookmarks.json", headers: {
      HTTP_USER_API_KEY: calendar_key.key,
    }
    expect(response.status).to eq(403) # Does not allow json

    get "/u/#{user.username}/bookmarks.ics", headers: {
      HTTP_USER_API_KEY: calendar_key.key,
    }
    expect(response.status).to eq(200) # Allows ICS

    # Now restrict the key
    calendar_key.scopes.first.update(allowed_parameters: { username: admin.username })

    get "/u/#{user.username}/bookmarks.ics", headers: {
      HTTP_USER_API_KEY: calendar_key.key,
    }
    expect(response.status).to eq(403) # Cannot access another users calendar

    get "/u/#{admin.username}/bookmarks.ics", headers: {
      HTTP_USER_API_KEY: calendar_key.key,
    }
    expect(response.status).to eq(200) # Can access own calendar
  end

  context "with a plugin registered user api key scope" do
    let(:user_api_key) { Fabricate(:user_api_key) }

    before do
      metadata = Plugin::Metadata.new
      metadata.name = "My Amazing Plugin"
      plugin = Plugin::Instance.new metadata
      plugin.add_user_api_key_scope :my_magic_scope, methods: :get, actions: "session#current"
      user_api_key.scopes = [UserApiKeyScope.new(name: "my-amazing-plugin:my_magic_scope")]
      user_api_key.save!
    end

    it 'allows parameter access to the registered route' do
      get '/session/current.json', headers: {
        HTTP_USER_API_KEY: user_api_key.key
      }
      expect(response.status).to eq(200)
    end
  end

end
