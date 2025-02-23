# frozen_string_literal: true

class EmailController < ApplicationController
  layout "no_ember"

  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required

  def unsubscribe
    key = UnsubscribeKey.includes(:user).find_by(key: params[:key])
    @found = key.present?
    @key_owner_found = key&.user.present?

    if @found && @key_owner_found
      UnsubscribeKey.get_unsubscribe_strategy_for(key)&.prepare_unsubscribe_options(self)

      if current_user.present? && (@user != current_user)
        @different_user = @user.name
        @return_url = request.original_url
      end
    end
  end

  def perform_unsubscribe
    RateLimiter.new(nil, "unsubscribe_#{request.ip}", 10, 1.minute).performed!

    key = UnsubscribeKey.includes(:user).find_by(key: params[:key])
    raise Discourse::NotFound if key.nil? || key.user.nil?
    user = key.user
    updated = UnsubscribeKey.get_unsubscribe_strategy_for(key)&.unsubscribe(params)

    if updated
      cache_key = "unsub_#{SecureRandom.hex}"
      Discourse.cache.write cache_key, user.email, expires_in: 1.hour

      url = path("/email/unsubscribed?key=#{cache_key}")
      url += "&topic_id=#{key.associated_topic.id}" if key.associated_topic

      redirect_to url
    else
      redirect_back fallback_location: path("/")
    end
  end

  def unsubscribed
    @email = Discourse.cache.read(params[:key])

    raise Discourse::NotFound unless User.find_by_email(@email)

    if @topic_id = params[:topic_id]
      topic = Topic.find_by(id: @topic_id)
      @topic = topic if topic && Guardian.new.can_see?(topic)
    end
  end
end
