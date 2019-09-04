# frozen_string_literal: true

require 'rails_helper'

describe EmailStyleUpdater do
  fab!(:admin) { Fabricate(:admin) }
  let(:default_html) { File.read("#{Rails.root}/app/views/email/default_template.html") }
  let(:updater) { EmailStyleUpdater.new(admin) }

  describe 'update' do
    it 'can change the settings' do
      expect(
        updater.update(
          html: 'For you: %{email_content}',
          css: 'h1 { color: blue; }'
        )
      ).to eq(true)
      expect(SiteSetting.email_custom_template).to eq('For you: %{email_content}')
      expect(SiteSetting.email_custom_css).to eq('h1 { color: blue; }')
    end

    it 'will not store defaults' do
      updater.update(html: default_html, css: '')
      expect(SiteSetting.email_custom_template).to_not be_present
      expect(SiteSetting.email_custom_css).to_not be_present
    end

    it 'can clear settings if defaults given' do
      SiteSetting.email_custom_template = 'For you: %{email_content}'
      SiteSetting.email_custom_css = 'h1 { color: blue; }'
      updater.update(html: default_html, css: '')
      expect(SiteSetting.email_custom_template).to_not be_present
      expect(SiteSetting.email_custom_css).to_not be_present
    end

    it 'fails if html is missing email_content' do
      expect(updater.update(html: 'No email content', css: '')).to eq(false)
      expect(updater.errors).to include(
        I18n.t(
          'email_style.html_missing_placeholder',
          placeholder: '%{email_content}'
        )
      )
    end
  end
end
