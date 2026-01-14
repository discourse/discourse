# frozen_string_literal: true

class SubscriptionsUserConstraint
  def matches?(request)
    provider = Discourse.current_user_provider.new(request.env)
    provider.current_user
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end
end
