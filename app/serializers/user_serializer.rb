class UserSerializer < BasicUserSerializer

  attributes :name,
             :email,
             :last_posted_at,
             :last_seen_at,
             :bio_raw,
             :bio_cooked,
             :created_at,
             :website,
             :can_edit,
             :stream,
             :stats,
             :can_send_private_message_to_user,
             :bio_excerpt,
             :invited_by,
             :trust_level,
             :moderator,
             :admin


  def self.private_attributes(*attrs)
    attributes *attrs
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        can_edit
      end
    end
  end

  def bio_excerpt
    e = object.bio_excerpt
    unless e && e.length > 0
      e = if scope.user && scope.user.id == object.id
        I18n.t('user_profile.no_info_me', username_lower: object.username_lower)
      else
        I18n.t('user_profile.no_info_other', name: object.name)
      end
    end
    e
  end

  private_attributes :email,
             :email_digests,
             :email_private_messages,
             :email_direct,
             :digest_after_days,
             :auto_track_topics_after_msecs,
             :new_topic_duration_minutes, 
             :external_links_in_new_tab,
             :enable_quoting 
             

  def auto_track_topics_after_msecs
    object.auto_track_topics_after_msecs || SiteSetting.auto_track_topics_after
  end

  def new_topic_duration_minutes
    object.new_topic_duration_minutes || SiteSetting.new_topic_duration_minutes
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
  end

  def stats
    UserAction.stats(object.id, scope)
  end

  def stream
    UserAction.stream(user_id: object.id, offset: 0, limit: 60, 
                      guardian: scope, ignore_private_messages: true)
  end

  def can_edit
    scope.can_edit?(object)
  end

end
