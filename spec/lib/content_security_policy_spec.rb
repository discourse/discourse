# frozen_string_literal: true
require 'rails_helper'

describe ContentSecurityPolicy do
  before { ContentSecurityPolicy.base_url = nil }

  describe 'report-uri' do
    it 'is enabled by SiteSetting' do
      SiteSetting.content_security_policy_collect_reports = true
      report_uri = parse(policy)['report-uri'].first
      expect(report_uri).to eq('http://test.localhost/csp_reports')

      SiteSetting.content_security_policy_collect_reports = false
      report_uri = parse(policy)['report-uri']
      expect(report_uri).to eq(nil)
    end
  end

  describe 'base-uri' do
    it 'is set to none' do
      base_uri = parse(policy)['base-uri']
      expect(base_uri).to eq(["'none'"])
    end
  end

  describe 'object-src' do
    it 'is set to none' do
      object_srcs = parse(policy)['object-src']
      expect(object_srcs).to eq(["'none'"])
    end
  end

  describe 'worker-src' do
    it 'always has self and blob' do
      worker_srcs = parse(policy)['worker-src']
      expect(worker_srcs).to eq(%w[
        'self'
        blob:
      ])
    end
  end

  describe 'script-src' do
    it 'always has self, logster, sidekiq, and assets' do
      script_srcs = parse(policy)['script-src']
      expect(script_srcs).to include(*%w[
        'unsafe-eval'
        'report-sample'
        http://test.localhost/logs/
        http://test.localhost/sidekiq/
        http://test.localhost/mini-profiler-resources/
        http://test.localhost/assets/
        http://test.localhost/brotli_asset/
        http://test.localhost/extra-locales/
        http://test.localhost/highlight-js/
        http://test.localhost/javascripts/
        http://test.localhost/plugins/
        http://test.localhost/theme-javascripts/
        http://test.localhost/svg-sprite/
      ])
    end

    it 'whitelists Google Analytics and Tag Manager when integrated' do
      SiteSetting.ga_universal_tracking_code = 'UA-12345678-9'
      SiteSetting.gtm_container_id = 'GTM-ABCDEF'

      script_srcs = parse(policy)['script-src']
      expect(script_srcs).to include('https://www.google-analytics.com/analytics.js')
      expect(script_srcs).to include('https://www.googletagmanager.com/gtm.js')
    end

    it 'whitelists CDN assets when integrated' do
      set_cdn_url('https://cdn.com')

      script_srcs = parse(policy)['script-src']
      expect(script_srcs).to include(*%w[
        https://cdn.com/assets/
        https://cdn.com/brotli_asset/
        https://cdn.com/highlight-js/
        https://cdn.com/javascripts/
        https://cdn.com/plugins/
        https://cdn.com/theme-javascripts/
        http://test.localhost/extra-locales/
      ])

      global_setting(:s3_cdn_url, 'https://s3-cdn.com')

      script_srcs = parse(policy)['script-src']
      expect(script_srcs).to include(*%w[
        https://s3-cdn.com/assets/
        https://s3-cdn.com/brotli_asset/
        https://cdn.com/highlight-js/
        https://cdn.com/javascripts/
        https://cdn.com/plugins/
        https://cdn.com/theme-javascripts/
        http://test.localhost/extra-locales/
      ])
    end
  end

  it 'can be extended by plugins' do
    plugin = Class.new(Plugin::Instance) do
      attr_accessor :enabled
      def enabled?
        @enabled
      end
    end.new(nil, "#{Rails.root}/spec/fixtures/plugins/csp_extension/plugin.rb")

    plugin.activate!
    Discourse.plugins << plugin

    plugin.enabled = true
    expect(parse(policy)['script-src']).to include('https://from-plugin.com')
    expect(parse(policy)['object-src']).to include('https://test-stripping.com')
    expect(parse(policy)['object-src']).to_not include("'none'")

    plugin.enabled = false
    expect(parse(policy)['script-src']).to_not include('https://from-plugin.com')

    Discourse.plugins.pop
  end

  it 'can be extended by themes' do
    policy # call this first to make sure further actions clear the cache

    theme = Fabricate(:theme)
    settings = <<~YML
      extend_content_security_policy:
        type: list
        default: 'script-src: from-theme.com'
    YML
    theme.set_field(target: :settings, name: :yaml, value: settings)
    theme.save!

    expect(parse(policy)['script-src']).to include('from-theme.com')

    theme.update_setting(:extend_content_security_policy, "script-src: https://from-theme.net|worker-src: from-theme.com")
    theme.save!

    expect(parse(policy)['script-src']).to_not include('from-theme.com')
    expect(parse(policy)['script-src']).to include('https://from-theme.net')
    expect(parse(policy)['worker-src']).to include('from-theme.com')

    theme.destroy!

    expect(parse(policy)['script-src']).to_not include('https://from-theme.net')
    expect(parse(policy)['worker-src']).to_not include('from-theme.com')
  end

  it 'can be extended by site setting' do
    SiteSetting.content_security_policy_script_src = 'from-site-setting.com|from-site-setting.net'

    expect(parse(policy)['script-src']).to include('from-site-setting.com', 'from-site-setting.net')
  end

  def parse(csp_string)
    csp_string.split(';').map do |policy|
      directive, *sources = policy.split
      [directive, sources]
    end.to_h
  end

  def policy
    ContentSecurityPolicy.policy
  end
end
