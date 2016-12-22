require 'excon'

module Jobs
  class EmitWebHookEvent < Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:web_hook_id) unless args[:web_hook_id].present?
      raise Discourse::InvalidParameters.new(:event_type) unless args[:event_type].present?

      args = args.dup

      web_hook = WebHook.find(args[:web_hook_id])

      unless args[:event_type] == 'ping'
        return unless web_hook.active?
        return if web_hook.group_ids.present? && (args[:group_id].present? ||
          !web_hook.group_ids.include?(args[:group_id]))
        return if web_hook.category_ids.present? && (!args[:category_id].present? ||
          !web_hook.category_ids.include?(args[:category_id]))

        model = args[:event_type].to_s
        record_id = "#{model}_id".to_sym
        return unless args[model] = WebHookEventType.const_get("#{model.classify}Type").load_record(args[record_id])
      end

      web_hook_request(args, web_hook)
    end

    private

    def build_web_hook_body(args, web_hook)
      body = {}
      guardian = Guardian.new(Discourse.system_user)

      if args[:event_type] == 'ping'
        body[:ping] = 'OK'
      else
        model = args[:event_type].to_s
        klass = WebHookEventType.const_get("#{model.classify}Type").serializer
        body[model] = klass.new(args[model], scope: guardian, root: false).as_json
      end

      raise Discourse::InvalidParameters.new if body.empty?

      new_body = Plugin::Filter.apply(:after_build_web_hook_body, self, body)

      Rails.logger.debug("Blank web hook body: #{args}") if new_body.blank?

      MultiJson.dump(new_body)
    end

    def web_hook_request(args, web_hook)
      uri = URI(web_hook.payload_url)
      conn = Excon.new(uri.to_s,
                       ssl_verify_peer: web_hook.verify_certificate,
                       retry_limit: 0)

      body = build_web_hook_body(args, web_hook)
      web_hook_event = WebHookEvent.create!(web_hook_id: web_hook.id)

      begin
        content_type = case web_hook.content_type
                       when WebHook.content_types['application/x-www-form-urlencoded']
                         'application/x-www-form-urlencoded'
                       else
                         'application/json'
                       end
        headers = {
          'Accept' => '*/*',
          'Connection' => 'close',
          'Content-Length' => body.bytesize,
          'Content-Type' => content_type,
          'Host' => uri.host,
          'User-Agent' => "Discourse/" + Discourse::VERSION::STRING,
          'X-Discourse-Instance' => Discourse.base_url,
          'X-Discourse-Event-Id' => web_hook_event.id,
          'X-Discourse-Event-Type' => args[:event_type]
        }
        headers['X-Discourse-Event'] = args[:event_name].to_s if args[:event_name].present?

        if web_hook.secret.present?
          headers['X-Discourse-Event-Signature'] = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", web_hook.secret, body)
        end

        now = Time.zone.now
        response = conn.post(headers: headers, body: body)

        web_hook_event.update_attributes!(headers: MultiJson.dump(headers),
                                          payload: body,
                                          status: response.status,
                                          response_headers: MultiJson.dump(response.headers),
                                          response_body: response.body,
                                          duration: ((Time.zone.now - now) * 1000).to_i)
        MessageBus.publish("/web_hook_events/#{web_hook.id}", {
          web_hook_event_id: web_hook_event.id,
          event_type: args[:event_type]
        }, user_ids: User.staff.pluck(:id))
      rescue
        web_hook_event.destroy!
      end
    end
  end
end
