require 'rails_helper'

describe ContentSecurityPolicy do
  describe 'report-uri' do
    it 'is enabled by SiteSetting' do
      SiteSetting.content_security_policy_collect_reports = true
      report_uri = parse(ContentSecurityPolicy.new.build)['report-uri'].first
      expect(report_uri).to eq('/csp_reports')

      SiteSetting.content_security_policy_collect_reports = false
      report_uri = parse(ContentSecurityPolicy.new.build)['report-uri']
      expect(report_uri).to eq(nil)
    end
  end

  describe 'worker-src' do
    it 'always has self and blob' do
      worker_srcs = parse(ContentSecurityPolicy.new.build)['worker-src']
      expect(worker_srcs).to eq(%w[
        'self'
        blob:
      ])
    end
  end

  describe 'script-src' do
    it 'always has self, logster, sidekiq, and assets' do
      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to eq(%w[
        'unsafe-eval'
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

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('https://www.google-analytics.com')
      expect(script_srcs).to include('https://www.googletagmanager.com')
    end

    it 'whitelists CDN assets when integrated' do
      set_cdn_url('https://cdn.com')

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
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

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
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

    it 'can be extended with more sources' do
      SiteSetting.content_security_policy_script_src = 'example.com|another.com'
      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('example.com')
      expect(script_srcs).to include('another.com')
      expect(script_srcs).to include("'unsafe-eval'")
    end
  end

  def parse(csp_string)
    csp_string.split(';').map do |policy|
      directive, *sources = policy.split
      [directive, sources]
    end.to_h
  end
end
