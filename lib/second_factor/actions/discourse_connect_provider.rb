# frozen_string_literal: true

module SecondFactor::Actions
  class DiscourseConnectProvider < Base
    def skip_second_factor_auth?(params)
      sso = get_sso(payload(params))
      !current_user || sso.logout || !sso.require_2fa || @opts[:confirmed_2fa_during_login]
    end

    def second_factor_auth_skipped!(params)
      sso = get_sso(payload(params))
      return { logout: true, return_sso_url: sso.return_sso_url } if sso.logout
      return { no_current_user: true } if !current_user
      populate_user_data(sso)
      sso.confirmed_2fa = true if @opts[:confirmed_2fa_during_login]
      { sso_redirect_url: sso.to_url(sso.return_sso_url) }
    end

    def no_second_factors_enabled!(params)
      sso = get_sso(payload(params))
      populate_user_data(sso)
      sso.no_2fa_methods = true
      { sso_redirect_url: sso.to_url(sso.return_sso_url) }
    end

    def second_factor_auth_required!(params)
      pl = payload(params)
      sso = get_sso(pl)
      hostname = URI(sso.return_sso_url).hostname
      {
        callback_params: {
          payload: pl,
        },
        callback_path: session_sso_provider_path,
        callback_method: "GET",
        description:
          I18n.t(
            "second_factor_auth.actions.discourse_connect_provider.description",
            hostname: hostname,
          ),
      }
    end

    def second_factor_auth_completed!(callback_params)
      sso = get_sso(callback_params[:payload])
      populate_user_data(sso)
      sso.confirmed_2fa = true
      { sso_redirect_url: sso.to_url(sso.return_sso_url) }
    end

    private

    def payload(params)
      return @opts[:payload] if @opts[:payload]
      params.require(:sso)
      request.query_string
    end

    def populate_user_data(sso)
      sso.name = current_user.name
      sso.username = current_user.username
      sso.email = current_user.email
      sso.external_id = current_user.id.to_s
      sso.admin = current_user.admin?
      sso.moderator = current_user.moderator?
      sso.groups = current_user.groups.pluck(:name).join(",")

      if current_user.uploaded_avatar.present?
        base_url =
          Discourse.store.external? ? "#{Discourse.store.absolute_base_url}/" : Discourse.base_url
        avatar_url =
          "#{base_url}#{Discourse.store.get_path_for_upload(current_user.uploaded_avatar)}"
        sso.avatar_url = UrlHelper.absolute Discourse.store.cdn_url(avatar_url)
      end

      if current_user.user_profile.profile_background_upload.present?
        sso.profile_background_url =
          UrlHelper.absolute(
            GlobalPath.upload_cdn_path(current_user.user_profile.profile_background_upload.url),
          )
      end

      if current_user.user_profile.card_background_upload.present?
        sso.card_background_url =
          UrlHelper.absolute(
            GlobalPath.upload_cdn_path(current_user.user_profile.card_background_upload.url),
          )
      end
    end

    def get_sso(payload)
      sso = ::DiscourseConnectProvider.parse(payload)
      raise ::DiscourseConnectProvider::BlankReturnUrl.new if sso.return_sso_url.blank?
      sso
    rescue ::DiscourseConnectProvider::ParseError => e
      if SiteSetting.verbose_discourse_connect_logging
        Rails.logger.warn(
          "Verbose SSO log: Signature parse error\n\n#{e.message}\n\n#{sso&.diagnostics}",
        )
      end
      raise
    end
  end
end
