# frozen_string_literal: true

require 'rails_helper'

describe BootstrapController do

  it "returns data as anonymous" do
    get "/bootstrap.json"
    expect(response.status).to eq(200)

    json = response.parsed_body
    expect(json).to be_present

    bootstrap = json['bootstrap']
    expect(bootstrap).to be_present
    expect(bootstrap['title']).to be_present
    expect(bootstrap['setup_data']['base_url']).to eq(Discourse.base_url)
    preloaded = bootstrap['preloaded']
    expect(preloaded['site']).to be_present
    expect(preloaded['siteSettings']).to be_present
    expect(preloaded['currentUser']).to be_blank
    expect(preloaded['topicTrackingStates']).to be_blank
  end

  it "returns user data when authenticated" do
    user = Fabricate(:user)
    sign_in(user)
    get "/bootstrap.json"
    expect(response.status).to eq(200)

    json = response.parsed_body
    expect(json).to be_present

    bootstrap = json['bootstrap']
    preloaded = bootstrap['preloaded']
    expect(preloaded['currentUser']).to be_present
    expect(preloaded['topicTrackingStates']).to be_present
  end

end
