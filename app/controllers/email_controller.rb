# frozen_string_literal: true

class EmailController < ApplicationController
  layout "no_ember"

  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required

  skip_before_action :verify_authenticity_token, only: [:unsubscribe], if: :one_click_unsubscribe?

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

    resolved_params = params.dup

    if params["List-Unsubscribe"] == "One-Click"
      # digests
      resolved_params["digest_after_minutes"] = 0

      # specific topics
      resolved_params["unwatch_topic"] = true
      resolved_params["unwatch_category"] = true

      # everything else (mailing list mode etc...)
      resolved_params["unsubscribe_all"] = true
    end

    updated = UnsubscribeKey.get_unsubscribe_strategy_for(key)&.unsubscribe(resolved_params)

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

  private

  def one_click_unsubscribe?
    request.post? && params["List-Unsubscribe"] == "One-Click"
  end
end
