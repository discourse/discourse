require 'excon'

module Jobs
  class EmitWebHookEvent < Jobs::Base
    PING_EVENT = 'ping'.freeze
    MAX_RETRY_COUNT = 4.freeze
    RETRY_BACKOFF = 5

    def execute(args)
      memoize_arguments(args)
      validate_arguments!

      unless ping_event?(arguments[:event_type])
        validate_argument!(:payload)

        return if webhook_inactive?
        return if group_webhook_invalid?
        return if category_webhook_invalid?
        return if tag_webhook_invalid?
      end

      send_webhook!
    end

    private

    def validate_arguments!
      validate_argument!(:web_hook_id)
      validate_argument!(:event_type)
      raise Discourse::InvalidParameters.new(:web_hook_id) if web_hook.blank?
    end

    def validate_argument!(key)
      raise Discourse::InvalidParameters.new(key) unless arguments[key].present?
    end

    def memoize_arguments(args)
      @arguments = args
      @retry_count = @arguments[:retry_count] || 0
    end

    def send_webhook!
      uri = URI(web_hook.payload_url.strip)

      conn = Excon.new(
        uri.to_s,
        ssl_verify_peer: web_hook.verify_certificate,
        retry_limit: 0
      )

      web_hook_body = build_webhook_body
      web_hook_event = create_webhook_event(web_hook_body)
      web_hook_headers = build_webhook_headers(uri, web_hook_body, web_hook_event)

      response = nil

      begin
        now = Time.zone.now
        response = conn.post(headers: web_hook_headers, body: web_hook_body)
        web_hook_event.update!(
          headers: MultiJson.dump(web_hook_headers),
          status: response.status,
          response_headers: MultiJson.dump(response.headers),
          response_body: response.body,
          duration: ((Time.zone.now - now) * 1000).to_i
        )
      rescue => e
        web_hook_event.update!(
          headers: MultiJson.dump(web_hook_headers),
          status: -1,
          response_headers: MultiJson.dump(error: e),
          duration: ((Time.zone.now - now) * 1000).to_i
        )
      end

      publish_webhook_event(web_hook_event)
      retry_web_hook if response&.status != 200
    end

    def retry_web_hook
      if SiteSetting.retry_web_hook_events?
        @retry_count += 1
        return if @retry_count > MAX_RETRY_COUNT
        delay = RETRY_BACKOFF ** (@retry_count - 1)
        Jobs.enqueue_in(delay.minutes, :emit_web_hook_event, arguments)
      end
    end

    def publish_webhook_event(web_hook_event)
      MessageBus.publish("/web_hook_events/#{web_hook.id}", {
        web_hook_event_id: web_hook_event.id,
        event_type: arguments[:event_type]
      }, user_ids: User.human_users.staff.pluck(:id))
    end

    def ping_event?(event_type)
      PING_EVENT == event_type
    end

    def webhook_inactive?
      !web_hook.active?
    end

    def group_webhook_invalid?
      web_hook.group_ids.present? && (arguments[:group_id].present? ||
        !web_hook.group_ids.include?(arguments[:group_id]))
    end

    def category_webhook_invalid?
      web_hook.category_ids.present? && (!arguments[:category_id].present? ||
        !web_hook.category_ids.include?(arguments[:category_id]))
    end

    def tag_webhook_invalid?
      web_hook.tag_ids.present? && (arguments[:tag_ids].blank? ||
        (web_hook.tag_ids & arguments[:tag_ids]).blank?)
    end

    def arguments
      @arguments
    end

    def parsed_payload
      @parsed_payload ||= JSON.parse(arguments[:payload])
    end

    def web_hook
      @web_hook ||= WebHook.find_by(id: arguments[:web_hook_id])
    end

    def build_webhook_headers(uri, web_hook_body, web_hook_event)
      content_type =
        case web_hook.content_type
        when WebHook.content_types['application/x-www-form-urlencoded']
          'application/x-www-form-urlencoded'
        else
          'application/json'
        end

      headers = {
        'Accept' => '*/*',
        'Connection' => 'close',
        'Content-Length' => web_hook_body.bytesize,
        'Content-Type' => content_type,
        'Host' => uri.host,
        'User-Agent' => "Discourse/#{Discourse::VERSION::STRING}",
        'X-Discourse-Instance' => Discourse.base_url,
        'X-Discourse-Event-Id' => web_hook_event.id,
        'X-Discourse-Event-Type' => arguments[:event_type]
      }

      headers['X-Discourse-Event'] = arguments[:event_name] if arguments[:event_name].present?

      if web_hook.secret.present?
        headers['X-Discourse-Event-Signature'] = "sha256=#{OpenSSL::HMAC.hexdigest("sha256", web_hook.secret, web_hook_body)}"
      end

      headers
    end

    def build_webhook_body
      body = {}

      if ping_event?(arguments[:event_type])
        body['ping'] = "OK"
      else
        body[arguments[:event_type]] = parsed_payload
      end

      new_body = Plugin::Filter.apply(:after_build_web_hook_body, self, body)
      MultiJson.dump(new_body)
    end

    def create_webhook_event(web_hook_body)
      WebHookEvent.create!(web_hook_id: web_hook.id, payload: web_hook_body)
    end

  end
end
