# frozen_string_literal: true

class WebHookEmitter
  REQUEST_TIMEOUT = 20

  def initialize(webhook, webhook_event)
    @webhook = webhook
    @webhook_event = webhook_event
  end

  def emit!(headers:, body:)
    uri = URI(@webhook.payload_url.strip)

    connection_opts = {
      request: {
        write_timeout: REQUEST_TIMEOUT,
        read_timeout: REQUEST_TIMEOUT,
        open_timeout: REQUEST_TIMEOUT,
      },
    }

    connection_opts[:ssl] = { verify: false } if !@webhook.verify_certificate

    conn = Faraday.new(nil, connection_opts) { |f| f.adapter FinalDestination::FaradayAdapter }

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    error = nil
    response = nil
    begin
      response = conn.post(uri.to_s, body, headers)
    rescue => e
      error = e
    end
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start
    event_update_args = { headers: MultiJson.dump(headers), duration: duration }
    if response
      event_update_args[:response_headers] = MultiJson.dump(response.headers)
      event_update_args[:response_body] = response.body
      event_update_args[:status] = response.status
    else
      event_update_args[:status] = -1
      if error.is_a?(Faraday::Error) &&
           error.wrapped_exception.is_a?(FinalDestination::SSRFDetector::DisallowedIpError)
        error = I18n.t("webhooks.payload_url.blocked_or_internal")
      end
      event_update_args[:response_headers] = MultiJson.dump(error: error)
    end
    @webhook_event.update!(**event_update_args)
    response
  end
end
