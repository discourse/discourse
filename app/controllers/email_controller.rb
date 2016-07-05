class EmailController < ApplicationController
  skip_before_filter :check_xhr, :preload_json, :redirect_to_login_if_required
  layout 'no_ember'

  before_filter :ensure_logged_in, only: :preferences_redirect

  def preferences_redirect
    redirect_to(email_preferences_path(current_user.username_lower))
  end

  def unsubscribe
    key = UnsubscribeKey.find_by(key: params[:key])

    if key
      @user = key.user
      post = key.post
      @topic = (post && post.topic) || key.topic
      @type = key.unsubscribe_key_type

      if current_user.present? && (@user != current_user)
        @different_user = @user.name
        @return_url = request.original_url
      end

      @watching_topic = @topic && TopicUser.exists?(user_id: @user.id,
                                                    notification_level: TopicUser.notification_levels[:watching],
                                                    topic_id: @topic.id)

      @watched_count = nil
      if @topic && @topic.category_id
        if CategoryUser.exists?(user_id: @user.id,
                                notification_level: CategoryUser.watching_levels,
                                category_id: @topic.category_id)
          @watched_count = TopicUser.joins(:topic)
                                    .where(:user => @user,
                                           :notification_level => TopicUser.notification_levels[:watching],
                                           "topics.category_id" => @topic.category_id
                                          ).count
        end
      end
    end

    if @user.blank?
      @not_found = true
    end

  end

  def perform_unsubscribe

    key = UnsubscribeKey.find_by(key: params[:key])
    unless key && key.user
      raise Discourse::NotFound
    end

    topic = (key.post && key.post.topic) || key.topic
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

    if params["disable_digest_emails"]
      user.user_option.update_columns(email_digests: false)
      updated = true
    end

    if params["unsubscribe_all"]
      user.user_option.update_columns(email_always: false,
                                     email_digests: false,
                                     email_direct: false,
                                     email_private_messages: false)
      updated = true
    end

    unless updated
      redirect_to :back
    else
      if topic
        redirect_to path("/email/unsubscribed?topic_id=#{topic.id}")
      else
        redirect_to path("/email/unsubscribed")
      end
    end

  end

  def unsubscribed
    @topic = Topic.find_by(id: params[:topic_id].to_i) if params[:topic_id]
  end

end
