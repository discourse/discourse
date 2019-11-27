# frozen_string_literal: true

class EmailController < ApplicationController
  layout 'no_ember'

  skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required
  before_action :ensure_logged_in, only: :preferences_redirect

  def preferences_redirect
    redirect_to(email_preferences_path(current_user.username_lower))
  end

  def unsubscribe
    @not_found = true
    @watched_count = nil

    if key = UnsubscribeKey.find_by(key: params[:key])
      if @user = key.user
        post = key.post
        @topic = post&.topic || key.topic
        @digest_unsubscribe = !@topic && !SiteSetting.disable_digest_emails
        @type = key.unsubscribe_key_type
        @not_found = false

        if current_user.present? && (@user != current_user)
          @different_user = @user.name
          @return_url = request.original_url
        end

        watching = TopicUser.notification_levels[:watching]

        if @topic
          @watching_topic = TopicUser.exists?(user_id: @user.id, notification_level: watching, topic_id: @topic.id)
          if @topic.category_id
            if CategoryUser.exists?(user_id: @user.id, notification_level: CategoryUser.watching_levels, category_id: @topic.category_id)
              @watched_count = TopicUser.joins(:topic)
                .where(user: @user, notification_level: watching, "topics.category_id" => @topic.category_id)
                .count
            end
          end
        else
          @digest_frequencies = digest_frequencies(@user)
        end
      end
    end
  end

  def perform_unsubscribe
    RateLimiter.new(nil, "unsubscribe_#{request.ip}", 10, 1.minute).performed!

    key = UnsubscribeKey.find_by(key: params[:key])
    raise Discourse::NotFound unless key && key.user

    topic = key&.post&.topic || key.topic
    user = key.user

    updated = false

    if topic
      if params["unwatch_topic"]
        TopicUser.where(topic_id: topic.id, user_id: user.id)
          .update_all(notification_level: TopicUser.notification_levels[:tracking])
        updated = true
      end

      if params["unwatch_category"] && topic.category_id
        TopicUser.joins(:topic)
          .where(:user => user,
                 :notification_level => TopicUser.notification_levels[:watching],
                 "topics.category_id" => topic.category_id)
          .update_all(notification_level: TopicUser.notification_levels[:tracking])

        CategoryUser.where(user_id: user.id,
                           category_id: topic.category_id,
                           notification_level: CategoryUser.watching_levels
                         )
          .destroy_all
        updated = true
      end

      if params["mute_topic"]
        TopicUser.where(topic_id: topic.id, user_id: user.id)
          .update_all(notification_level: TopicUser.notification_levels[:muted])
        updated = true
      end
    end

    if params["disable_mailing_list"]
      user.user_option.update_columns(mailing_list_mode: false)
      updated = true
    end

    if params['digest_after_minutes']
      digest_frequency = params['digest_after_minutes'].to_i

      user.user_option.update_columns(
        digest_after_minutes: digest_frequency,
        email_digests: digest_frequency.positive?
      )
      updated = true
    end

    if params["unsubscribe_all"]
      user.user_option.update_columns(email_digests: false,
                                      email_level: UserOption.email_level_types[:never],
                                      email_messages_level: UserOption.email_level_types[:never])
      updated = true
    end

    unless updated
      redirect_back fallback_location: path("/")
    else

      key = "unsub_#{SecureRandom.hex}"
      Discourse.cache.write key, user.email, expires_in: 1.hour

      url = path("/email/unsubscribed?key=#{key}")
      if topic
        url += "&topic_id=#{topic.id}"
      end

      redirect_to url
    end

  end

  def unsubscribed
    @email = Discourse.cache.read(params[:key])
    @topic_id = params[:topic_id]
    user = User.find_by_email(@email)
    raise Discourse::NotFound unless user
    topic = Topic.find_by(id: params[:topic_id].to_i) if @topic_id
    @topic = topic if topic && Guardian.new(nil).can_see?(topic)
  end

  private

  def digest_frequencies(user)
    frequency_in_minutes = user.user_option.digest_after_minutes
    frequencies = DigestEmailSiteSetting.values.dup
    never = frequencies.delete_at(0)
    allowed_frequencies = %w[never weekly every_month every_six_months]

    result = frequencies.reduce(frequencies: [], current: nil, selected: nil, take_next: false) do |memo, v|
      memo[:current] = v[:name] if v[:value] == frequency_in_minutes
      next(memo) unless allowed_frequencies.include?(v[:name])

      memo.tap do |m|
        m[:selected] = v[:value] if m[:take_next]
        m[:frequencies] << [I18n.t("unsubscribe.digest_frequency.#{v[:name]}"), v[:value]]
        m[:take_next] = !m[:take_next] && m[:current]
      end
    end

    result.slice(:frequencies, :current, :selected).tap do |r|
      r[:frequencies] << [I18n.t("unsubscribe.digest_frequency.#{never[:name]}"), never[:value]]
      r[:selected] ||= never[:value]
      r[:current] ||= never[:name]
    end
  end
end
