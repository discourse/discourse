# frozen_string_literal: true

module DiscourseNarrativeBot
  class CertificatesController < ::ApplicationController
    requires_plugin DiscourseNarrativeBot::PLUGIN_NAME
    layout false
    skip_before_action :check_xhr
    requires_login

    def generate
      immutable_for(24.hours)

      %i[date user_id].each do |key|
        raise Discourse::InvalidParameters.new("#{key} must be present") if params[key].blank?
      end

      if params[:user_id].to_i != current_user.id
        rate_limiter = RateLimiter.new(current_user, "svg_certificate", 3, 1.minute)
      else
        rate_limiter = RateLimiter.new(current_user, "svg_certificate_self", 30, 10.minutes)
      end
      rate_limiter.performed! unless current_user.staff?

      user = User.find_by(id: params[:user_id])
      raise Discourse::NotFound if user.blank?

      hijack do
        generator = CertificateGenerator.new(user, params[:date], avatar_url(user))

        svg = params[:type] == "advanced" ? generator.advanced_user_track : generator.new_user_track

        respond_to { |format| format.svg { render inline: svg } }
      end
    end

    private

    def avatar_url(user)
      UrlHelper.absolute(Discourse.base_path + user.avatar_template.gsub("{size}", "250"))
    end
  end
end
