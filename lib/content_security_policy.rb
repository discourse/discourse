# frozen_string_literal: true
class ContentSecurityPolicy
  include GlobalPath

  def initialize
    @directives = {
      script_src: script_src,
    }

    @directives[:report_uri] = path('/csp_reports') if SiteSetting.content_security_policy_collect_reports
  end

  def build
    policy = ActionDispatch::ContentSecurityPolicy.new

    @directives.each do |directive, sources|
      if sources.is_a?(Array)
        policy.public_send(directive, *sources)
      else
        policy.public_send(directive, sources)
      end
    end

    policy.build
  end

  private

  def script_src
    sources = [:self, :unsafe_eval]

    sources << :https if SiteSetting.force_https
    sources << Discourse.asset_host if Discourse.asset_host.present?
    sources << 'www.google-analytics.com' if SiteSetting.ga_universal_tracking_code.present?
    sources << 'www.googletagmanager.com' if SiteSetting.gtm_container_id.present?

    sources.concat(SiteSetting.content_security_policy_script_src.split('|'))
  end
end
