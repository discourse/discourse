module Jobs
  class EmitWebHookEvent < Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:web_hook_id) unless args[:web_hook_id].present?
      unless args[:event_name].present? && WebHookEventType.find_by(name: args[:event_name])
        raise Discourse::InvalidParameters.new(:event_name)
      end

      # TODO: building a event and catch and cancel previous events to prevent using row level lock
      @web_hook = WebHook.find(args[:web_hook_id])

      return unless @web_hook.active?
      return if @web_hook.group_ids.present? && (args[:group_id].present? ||
        !@web_hook.group_ids.include?(args[:group_id]))
      return if @web_hook.category_ids.present? && (!args[:category_id].present? ||
        !@web_hook.category_ids.include?(args[:category_id]))

      @opts = args

      web_hook_request
    end

    private

    def web_hook_request
      uri = URI(@web_hook.payload_url)

      conn = Excon.new(uri.to_s, ssl_verify_peer: @web_hook.verify_certificate)

      headers = {
        'Host' => uri.host,
        'X-Discourse-Event' => @opts[:event_name]
      }

      headers['Content-Type'] = case @web_hook.content_type
                                when WebHook.content_types['application/x-www-form-urlencoded']
                                  'application/x-www-form-urlencoded'
                                else
                                  'application/json'
                                end

      body = build_web_hook_body

      if @web_hook.secret.present?
        headers['X-Discourse-Event-Signature'] = OpenSSL::HMAC.hexdigest("sha256", @web_hook.secret, body)
      end

      conn.post(headers: headers, body: body)
    end

    def build_web_hook_body
      body = {}
      web_hook_user = Discourse.system_user
      guardian = Guardian.new(web_hook_user)

      if @opts[:topic_id]
        topic_view = TopicView.new(@opts[:topic_id], web_hook_user)
        body[:topic] = WebHooksTopicSerializer.new(topic_view, scope: guardian, root: false).as_json
      end

      if @opts[:post_id]
        post = Post.find(@opts[:post_id])
        body[:post] = WebHooksPostSerializer.new(post, scope: guardian, root: false).as_json
      end

      if @opts[:user_id]
        user = User.find(@opts[:user_id])
        body[:user] = WebHooksUserSerializer.new(user, scope: guardian, root: false).as_json
      end

      raise Discourse::InvalidParameters.new if body.empty?

      MultiJson.dump(body).rstrip + "\n"
    end

  end

end
