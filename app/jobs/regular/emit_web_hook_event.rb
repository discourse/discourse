require 'excon'

module Jobs
  class EmitWebHookEvent < Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:web_hook_id) unless args[:web_hook_id].present?
      raise Discourse::InvalidParameters.new(:event_type) unless args[:event_type].present?

      @web_hook = WebHook.find(args[:web_hook_id])

      unless args[:event_type] == 'ping'
        return unless @web_hook.active?
        return if @web_hook.group_ids.present? && (args[:group_id].present? ||
          !@web_hook.group_ids.include?(args[:group_id]))
        return if @web_hook.category_ids.present? && (!args[:category_id].present? ||
          !@web_hook.category_ids.include?(args[:category_id]))
      end

      @opts = args

      web_hook_request
    end

    private

    def web_hook_request
      uri = URI(@web_hook.payload_url)
      conn = Excon.new(uri.to_s,
                       ssl_verify_peer: @web_hook.verify_certificate,
                       retry_limit: 0)

      body = build_web_hook_body
      web_hook_event = WebHookEvent.create!(web_hook_id: @web_hook.id)

      begin
        content_type = case @web_hook.content_type
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
          'X-Discourse-Event-Id' => web_hook_event.id,
          'X-Discourse-Event-Type' => @opts[:event_type]
        }
        headers['X-Discourse-Event'] = @opts[:event_name].to_s if @opts[:event_name].present?

        if @web_hook.secret.present?
          headers['X-Discourse-Event-Signature'] = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", @web_hook.secret, body)
        end

        now = Time.zone.now
        response = conn.post(headers: headers, body: body)
      rescue
        web_hook_event.destroy!
      end

      web_hook_event.update_attributes!(headers: MultiJson.dump(headers),
                                        payload: body,
                                        status: response.status,
                                        response_headers: MultiJson.dump(response.headers),
                                        response_body: response.body,
                                        duration: ((Time.zone.now - now) * 1000).to_i)
      MessageBus.publish("/web_hook_events/#{@web_hook.id}", {
        web_hook_event_id: web_hook_event.id,
        event_type: @opts[:event_type]
      }, user_ids: User.staff.pluck(:id))
    end

    def build_web_hook_body
      body = {}
      web_hook_user = Discourse.system_user
      guardian = Guardian.new(web_hook_user)

      if @opts[:topic_id]
        topic_view = TopicView.new(@opts[:topic_id], web_hook_user)
        body[:topic] = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json
      end

      if @opts[:post_id]
        post = Post.find(@opts[:post_id])
        body[:post] = PostSerializer.new(post, scope: guardian, root: false).as_json
      end

      if @opts[:user_id]
        user = User.find(@opts[:user_id])
        body[:user] = UserSerializer.new(user, scope: guardian, root: false).as_json
      end

      body[:ping] = 'OK' if @opts[:event_type] == 'ping'

      raise Discourse::InvalidParameters.new if body.empty?

      MultiJson.dump(body)
    end

  end

end
