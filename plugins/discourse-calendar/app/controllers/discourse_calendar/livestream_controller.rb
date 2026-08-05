# frozen_string_literal: true

module DiscourseCalendar
  class LivestreamController < ::ApplicationController
    requires_plugin DiscourseCalendar::PLUGIN_NAME
    requires_login except: %i[zoom_webhook]

    skip_before_action :check_xhr, only: %i[zoom_webhook]
    skip_before_action :verify_authenticity_token, only: %i[zoom_webhook]
    skip_before_action :redirect_to_login_if_required, only: %i[zoom_webhook]

    WEBHOOK_TIMESTAMP_TOLERANCE = 5.minutes

    def prepare_zoom_signature
      DiscourseCalendar::Livestream::PrepareZoomJoin.call(
        service_params.deep_merge(params: { topic_id: params[:topic_id] }),
      ) do |result|
        on_success { |zoom_join_payload:| render json: zoom_join_payload }

        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { raise Discourse::NotFound }
      end
    end

    # Zoom calls this to say a webinar has started, which is the only signal
    # that an attendee waiting for the host can be let in. Unauthenticated by
    # necessity, so the signature is the only thing standing in front of it.
    def zoom_webhook
      secret = SiteSetting.livestream_zoom_webhook_secret_token
      return head :not_found if secret.blank?

      body = request.body.read
      return head :forbidden if !valid_zoom_signature?(body, secret)

      payload = parse_zoom_payload(body)
      return head :bad_request if payload.blank?

      case payload["event"]
      when "endpoint.url_validation"
        plain_token = payload.dig("payload", "plainToken").to_s

        render json: {
                 plainToken: plain_token,
                 encryptedToken: OpenSSL::HMAC.hexdigest("SHA256", secret, plain_token),
               }
      when "meeting.started", "webinar.started"
        update_live_state(payload, live: true)
      when "meeting.ended", "webinar.ended"
        update_live_state(payload, live: false)
      else
        head :ok
      end
    end

    private

    def valid_zoom_signature?(body, secret)
      timestamp = request.headers["x-zm-request-timestamp"].to_s
      signature = request.headers["x-zm-signature"].to_s

      return false if timestamp.blank? || signature.blank?
      return false if (Time.now.to_i - timestamp.to_i).abs > WEBHOOK_TIMESTAMP_TOLERANCE.to_i

      expected = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "v0:#{timestamp}:#{body}")}"

      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def parse_zoom_payload(body)
      parsed = JSON.parse(body)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def update_live_state(payload, live:)
      DiscourseCalendar::Livestream::UpdateZoomLiveState.call(
        service_params.deep_merge(
          params: {
            meeting_number: payload.dig("payload", "object", "id").to_s,
            live: live,
          },
        ),
      ) do |result|
        on_failed_contract { head :bad_request }
        # Zoom reports on every meeting the account owns, so one nothing here
        # points at is expected rather than an error.
        on_model_not_found(:events) { head :ok }
        on_success { head :ok }
        on_failure { head :ok }
      end
    end
  end
end
