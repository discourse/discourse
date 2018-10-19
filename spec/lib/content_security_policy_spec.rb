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

  describe 'script-src defaults' do
    it 'always have self and unsafe-eval' do
      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to eq(%w['self' 'unsafe-eval'])
    end

    it 'enforces https when SiteSetting.force_https' do
      SiteSetting.force_https = true

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('https:')
    end

    it 'whitelists Google Analytics and Tag Manager when integrated' do
      SiteSetting.ga_universal_tracking_code = 'UA-12345678-9'
      SiteSetting.gtm_container_id = 'GTM-ABCDEF'

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('www.google-analytics.com')
      expect(script_srcs).to include('www.googletagmanager.com')
    end

    it 'whitelists CDN when integrated' do
      set_cdn_url('cdn.com')

      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('cdn.com')
    end

    it 'can be extended with more sources' do
      SiteSetting.content_security_policy_script_src = 'example.com|another.com'
      script_srcs = parse(ContentSecurityPolicy.new.build)['script-src']
      expect(script_srcs).to include('example.com')
      expect(script_srcs).to include('another.com')
      expect(script_srcs).to include("'unsafe-eval'")
      expect(script_srcs).to include("'self'")
    end
  end

  def parse(csp_string)
    csp_string.split(';').map do |policy|
      directive, *sources = policy.split
      [directive, sources]
    end.to_h
  end
end
