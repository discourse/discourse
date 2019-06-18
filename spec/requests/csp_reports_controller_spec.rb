# frozen_string_literal: true

require 'rails_helper'

describe CspReportsController do
  describe '#create' do
    before do
      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_collect_reports = true

      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after do
      Rails.logger = @orig_logger
    end

    def send_report
      post '/csp_reports', params: {
        "csp-report": {
          "document-uri": "http://localhost:3000/",
          "referrer": "",
          "violated-directive": "script-src",
          "effective-directive": "script-src",
          "original-policy": "script-src 'unsafe-eval' www.google-analytics.com; report-uri /csp_reports",
          "disposition": "report",
          "blocked-uri": "http://suspicio.us/assets.js",
          "line-number": 25,
          "source-file": "http://localhost:3000/",
          "status-code": 200,
          "script-sample": ""
        }
      }.to_json, headers: { "Content-Type": "application/csp-report" }
    end

    it 'is enabled by SiteSetting' do
      SiteSetting.content_security_policy = false
      SiteSetting.content_security_policy_report_only = false
      SiteSetting.content_security_policy_collect_reports = true
      send_report
      expect(response.status).to eq(200)

      SiteSetting.content_security_policy = true
      send_report
      expect(response.status).to eq(200)

      SiteSetting.content_security_policy_collect_reports = false
      send_report
      expect(response.status).to eq(404)
    end

    it 'logs the violation report' do
      send_report
      expect(Rails.logger.warnings).to include("CSP Violation: 'http://suspicio.us/assets.js'")
    end
  end
end
