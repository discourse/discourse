# frozen_string_literal: true

require "openssl"
require "json"

class Patreon::PatreonWebhookController < ApplicationController
  requires_plugin Patreon::PLUGIN_NAME

  skip_before_action :redirect_to_login_if_required,
                     :preload_json,
                     :check_xhr,
                     :verify_authenticity_token

  TRIGGERS = %w[
    pledges:create
    pledges:update
    pledges:delete
    members:create
    members:update
    members:delete
    members:pledge:create
    members:pledge:update
    members:pledge:delete
  ].freeze

  def index
    if unknown_trigger?
      message = event.blank? ? "Missing event header" : "Unknown event: #{event}"
      Rails.logger.warn("Patreon Webhook failed: #{message}") if SiteSetting.patreon_verbose_log
      render_json_error(message, status: 403)
      return
    end

    if !valid_signature?
      if SiteSetting.patreon_verbose_log
        Rails.logger.warn("Patreon Webhook failed: Invalid signature")
      end
      render_json_error("Invalid signature", status: 403)
      return
    end

    pledge_data = JSON.parse(request.body.read)
    adapter = Patreon::ApiVersion.adapter_for_payload(pledge_data)
    patreon_id = Patreon::Pledge.get_patreon_id(pledge_data, adapter: adapter)

    if SiteSetting.patreon_verbose_log
      Rails.logger.warn(
        "Patreon verbose log for Webhook:\n  Event = #{event}\n Id = #{patreon_id}\n  Data = #{pledge_data.inspect}",
      )
    end

    case event
    when /create$/
      Patreon::Pledge.create!(pledge_data, adapter: adapter)
    when /update$/
      Patreon::Pledge.update!(pledge_data, adapter: adapter)
    when /delete$/
      Patreon::Pledge.delete!(pledge_data, adapter: adapter)
    end

    Jobs.enqueue(:sync_patron_groups, patreon_id: patreon_id)

    render body: nil, status: :ok
  end

  def event
    request.headers["X-Patreon-Event"]
  end

  def unknown_trigger?
    TRIGGERS.exclude?(event)
  end

  private

  def valid_signature?
    secret = SiteSetting.patreon_webhook_secret
    return false if secret.blank?

    signature = request.headers["X-Patreon-Signature"]
    digest = OpenSSL::Digest.new("MD5")

    ActiveSupport::SecurityUtils.secure_compare(
      signature.to_s,
      OpenSSL::HMAC.hexdigest(digest, secret, request.raw_post),
    )
  end
end
