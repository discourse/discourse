# frozen_string_literal: true
class CspReportsController < ApplicationController
  skip_before_action :check_xhr, :preload_json, :verify_authenticity_token, only: [:create]

  def create
    raise Discourse::NotFound unless report_collection_enabled?

    Logster.add_to_env(request.env, 'CSP Report', report)
    Rails.logger.warn("CSP Violation: '#{report['blocked-uri']}'")

    head :ok
  end

  private

  def report
    @report ||= JSON.parse(request.body.read)['csp-report'].slice(
      'blocked-uri',
      'disposition',
      'document-uri',
      'effective-directive',
      'original-policy',
      'referrer',
      'script-sample',
      'status-code',
      'violated-directive',
      'line-number',
      'source-file'
    )
  end

  def report_collection_enabled?
    SiteSetting.content_security_policy_collect_reports
  end
end
