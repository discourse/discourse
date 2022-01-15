# frozen_string_literal: true

require 'rails_helper'
require 'site_settings/yaml_loader'

describe SiteSettings::YamlLoader do

  class Receiver
    attr_reader :settings, :client_settings, :categories

    def load_yaml(file_arg)
      SiteSettings::YamlLoader.new(file_arg).load do |category, name, default, opts|
        setting(category, name, default, opts)
      end
    end

    def setting(category, name, default = nil, opts = {})
      @settings ||= []
      @client_settings ||= []
      @settings << name
      @categories ||= []
      @categories << category
      @categories.uniq!
      @client_settings << name if opts.has_key?(:client)
    end
  end

  let!(:receiver)   { Receiver.new }
  let(:simple)      { "#{Rails.root}/spec/fixtures/site_settings/simple.yml" }
  let(:client)      { "#{Rails.root}/spec/fixtures/site_settings/client.yml" }
  let(:enum)        { "#{Rails.root}/spec/fixtures/site_settings/enum.yml" }
  let(:enum_client) { "#{Rails.root}/spec/fixtures/site_settings/enum_client.yml" }
  let(:deprecated_env) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_env.yml" }
  let(:deprecated_hidden) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_hidden.yml" }
  let(:locale_default) { "#{Rails.root}/spec/fixtures/site_settings/locale_default.yml" }
  let(:nil_default) { "#{Rails.root}/spec/fixtures/site_settings/nil_default.yml" }

  it "loads simple settings" do
    receiver.expects(:setting).with('category1', 'title', 'My Site', {}).once
    receiver.expects(:setting).with('category1', 'contact_email', 'webmaster@example.com', {}).once
    receiver.expects(:setting).with('category2', 'editing_grace_period', true, {}).once
    receiver.expects(:setting).with('category3', 'reply_by_email_address', '', {}).once
    receiver.load_yaml(simple)
  end

  it 'can take a File argument' do
    receiver.expects(:setting).at_least_once
    receiver.load_yaml(File.new(simple))
  end

  it "maintains order of categories" do
    receiver.load_yaml(simple)
    expect(receiver.categories).to eq(['category1', 'category2', 'category3'])
  end

  it "can load client settings" do
    receiver.expects(:setting).with('category1', 'title', 'Discourse', client: true)
    receiver.expects(:setting).with('category2', 'tos_url', '', client: true)
    receiver.expects(:setting).with('category2', 'must_approve_users', false, client: true)
    receiver.load_yaml(client)
  end

  it "can load enum settings" do
    receiver.expects(:setting).with('email', 'default_email_digest_frequency', 7, enum: 'DigestEmailSiteSetting')
    receiver.load_yaml(enum)
  end

  it "can load enum client settings" do
    receiver.expects(:setting).with do |category, name, default, opts|
      category == ('basics') && name == ('default_locale') && default == ('en') && opts[:enum] == ('LocaleSiteSetting') && opts[:client] == true
    end
    receiver.load_yaml(enum_client)
  end

  it "raises invalid parameter when default value is not present" do
    expect { receiver.load_yaml(nil_default) }.to raise_error(StandardError)
  end

  it "can load settings with locale default" do
    receiver.expects(:setting).with('search', 'min_search_term_length', 3, min: 2, client: true, locale_default: { zh_CN: 2, zh_TW: 2 })
    receiver.load_yaml(locale_default)
  end
end
