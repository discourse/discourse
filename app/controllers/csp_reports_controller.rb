# frozen_string_literal: true
class CspReportsController < ApplicationController
  skip_before_action :check_xhr, :verify_authenticity_token, only: [:create]

  def create
    raise Discourse::NotFound unless report_collection_enabled?

    report = parse_report

    if report.blank?
      render_json_error("empty CSP report", status: 422)
    else
      Logster.add_to_env(request.env, "CSP Report", report)
      Rails.logger.warn("CSP Violation: '#{report["blocked-uri"]}' \n\n#{report["script-sample"]}")

      head :ok
    end
  rescue JSON::ParserError
    render_json_error("invalid CSP report", status: 422)
  end

  private

  def parse_report
    obj = JSON.parse(request.body.read)
    if Hash === obj
      obj = obj["csp-report"]
      if Hash === obj
        obj.slice(
          "blocked-uri",
          "disposition",
          "document-uri",
          "effective-directive",
          "original-policy",
          "referrer",
          "script-sample",
          "status-code",
          "violated-directive",
          "line-number",
          "source-file",
        )
      end
    end
  end

  def report_collection_enabled?
    SiteSetting.content_security_policy_collect_reports
  end
end
