# frozen_string_literal: true

# Lets anonymous users initiate actions that require an account.
#
# Clicking such an action stores the intent in a signed, short-lived cookie,
# then redirects to login/signup. When `CurrentUser#log_on_user` completes the
# authentication, the matching handler runs against the freshly-authed user
# and the cookie is cleared.
#
# Handlers are registered by name. Each handler receives `(user, params)` and
# must reuse the same service the user-initiated path would use, so guardian
# and policy checks remain authoritative.
#
# Example:
#   AnonymousAction.register("like_post") do |user, params|
#     post = Post.find_by(id: params["post_id"])
#     next if !post || !user.guardian.can_see?(post)
#     PostActionCreator.like(user, post)
#   end
class AnonymousAction
  COOKIE = :_pending_anonymous_action
  EXPIRES_IN = 5.minutes

  class << self
    def register(type, &handler)
      handlers[type.to_s] = handler
    end

    def registered?(type)
      handlers.key?(type.to_s)
    end

    def handler_for(type)
      handlers[type.to_s]
    end

    def set(cookies, type:, params: {})
      raise Discourse::InvalidParameters.new(:type) if !registered?(type)

      cookies.signed[COOKIE] = cookie_options.merge(
        value: {
          "type" => type.to_s,
          "params" => params.to_h,
        },
        expires: EXPIRES_IN.from_now,
      )
    end

    def consume(user, cookies)
      data = cookies.signed[COOKIE]
      return if !data.is_a?(Hash)

      cookies.delete(COOKIE, **cookie_options)

      type = data["type"]
      handler = handler_for(type)
      return if !handler

      handler.call(user, data["params"] || {})
    rescue => e
      Discourse.warn_exception(
        e,
        message: "AnonymousAction handler failed for type: #{type.inspect}",
      )
    end

    def unregister(type)
      handlers.delete(type.to_s)
    end

    private

    def handlers
      @handlers ||= {}
    end

    def cookie_options
      { path: "/", httponly: true, same_site: :lax, secure: SiteSetting.force_https }
    end
  end
end
