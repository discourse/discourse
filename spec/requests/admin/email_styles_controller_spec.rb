# frozen_string_literal: true

require 'rails_helper'

describe Admin::EmailStylesController do
  fab!(:admin) { Fabricate(:admin) }
  let(:default_html) { File.read("#{Rails.root}/app/views/email/default_template.html") }
  let(:default_css) { "" }

  before do
    sign_in(admin)
  end

  after do
    SiteSetting.remove_override!(:email_custom_template)
    SiteSetting.remove_override!(:email_custom_css)
  end

  describe 'show' do
    it 'returns default values' do
      get '/admin/customize/email_style.json'
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)['email_style']
      expect(json['html']).to eq(default_html)
      expect(json['css']).to eq(default_css)
    end

    it 'returns customized values' do
      SiteSetting.email_custom_template = "For you: %{email_content}"
      SiteSetting.email_custom_css = ".user-name { font-size: 24px; }"
      get '/admin/customize/email_style.json'
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)['email_style']
      expect(json['html']).to eq("For you: %{email_content}")
      expect(json['css']).to eq(".user-name { font-size: 24px; }")
    end
  end

  describe 'update' do
    let(:valid_params) do
      {
        html: 'For you: %{email_content}',
        css: '.user-name { color: purple; }'
      }
    end

    it 'changes the settings' do
      SiteSetting.email_custom_css = ".user-name { font-size: 24px; }"
      put '/admin/customize/email_style.json', params: { email_style: valid_params }
      expect(response.status).to eq(200)
      expect(SiteSetting.email_custom_template).to eq(valid_params[:html])
      expect(SiteSetting.email_custom_css).to eq(valid_params[:css])
    end

    it 'reports errors' do
      put '/admin/customize/email_style.json', params: {
        email_style: valid_params.merge(html: 'No email content')
      }
      expect(response.status).to eq(422)
      json = JSON.parse(response.body)
      expect(json['errors']).to include(
        I18n.t(
          'email_style.html_missing_placeholder',
          placeholder: '%{email_content}'
        )
      )
    end
  end
end
