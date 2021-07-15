# frozen_string_literal: true

require 'rails_helper'

describe BootstrapController do

  let(:theme) { Fabricate(:theme, enabled: true) }

  before do
    DiscoursePluginRegistry.register_html_builder('server:before-head-close') { '<b>wat</b>' }
    theme.set_field(target: :desktop, name: :header, value: '<h1>custom header</h1>').save
    SiteSetting.default_theme_id = theme.id
  end

  after do
    DiscoursePluginRegistry.reset!
    ExtraLocalesController.clear_cache!
  end

  it "returns data as anonymous" do
    get "/bootstrap.json"
    expect(response.status).to eq(200)

    json = response.parsed_body
    expect(json).to be_present

    bootstrap = json['bootstrap']
    expect(bootstrap).to be_present
    expect(bootstrap['title']).to be_present
    expect(bootstrap['theme_id']).to eq(theme.id)
    expect(bootstrap['setup_data']['base_url']).to eq(Discourse.base_url)
    expect(bootstrap['stylesheets']).to be_present

    expect(bootstrap['html']).to be_present
    expect(bootstrap['html']['before_head_close']).to eq('<b>wat</b>')

    expect(bootstrap['theme_html']).to be_present
    expect(bootstrap['theme_html']['header']).to eq('<h1>custom header</h1>')

    preloaded = bootstrap['preloaded']
    expect(preloaded['site']).to be_present
    expect(preloaded['siteSettings']).to be_present
    expect(preloaded['currentUser']).to be_blank
    expect(preloaded['topicTrackingStates']).to be_blank

    expect(bootstrap['html_classes']).to eq("desktop-view not-mobile-device text-size-normal anon")
    expect(bootstrap['html_lang']).to eq('en')
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

  it "returns extra locales (admin) when staff" do
    user = Fabricate(:admin)
    sign_in(user)
    get "/bootstrap.json"
    expect(response.status).to eq(200)

    json = response.parsed_body
    expect(json).to be_present

    bootstrap = json['bootstrap']
    expect(bootstrap['extra_locales']).to be_present
  end

  it "returns data when login_required is enabled" do
    SiteSetting.login_required = true
    get "/bootstrap.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body).to be_present
  end
end
