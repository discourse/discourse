TopicStatusUpdate = Struct.new(:topic, :user) do
  def update!(status, enabled, opts={})
    status = Status.new(status, enabled)

    Topic.transaction do
      change(status, opts)
      highest_post_number = topic.highest_post_number
      create_moderator_post_for(status, opts[:message])
      update_read_state_for(status, highest_post_number)
    end
  end

  private

  def change(status, opts={})
    if status.pinned? || status.pinned_globally?
      topic.update_pinned(status.enabled?, status.pinned_globally?, opts[:until])
    elsif status.autoclosed?
      topic.update_column('closed', status.enabled?)
    else
      topic.update_column(status.name, status.enabled?)
    end

    if topic.auto_close_at && (status.reopening_topic? || status.manually_closing_topic?)
      topic.reload.set_auto_close(nil).save
    end

    # remove featured topics if we close/archive/make them invisible. Previously we used
    # to run the whole featuring logic but that could be very slow and have concurrency
    # errors on large sites with many autocloses and topics being created.
    if ((status.enabled? && (status.autoclosed? || status.closed? || status.archived?)) ||
        (status.disabled? && status.visible?))
      CategoryFeaturedTopic.where(topic_id: topic.id).delete_all
    end
  end

  def create_moderator_post_for(status, message=nil)
    topic.add_moderator_post(user, message || message_for(status), options_for(status))
    topic.reload
  end

  def update_read_state_for(status, old_highest_read)
    if status.autoclosed?
      # let's pretend all the people that read up to the autoclose message
      # actually read the topic
      PostTiming.pretend_read(topic.id, old_highest_read, topic.highest_post_number)
    end
  end

  def message_for(status)
    if status.autoclosed?
      locale_key = status.locale_key
      locale_key << "_lastpost" if topic.auto_close_based_on_last_post
      message_for_autoclosed(locale_key)
    end
  end

  def message_for_autoclosed(locale_key)
    num_minutes = ((
                    if topic.auto_close_based_on_last_post
                      topic.auto_close_hours.hours
                    elsif topic.auto_close_started_at
                      Time.zone.now - topic.auto_close_started_at
                    else
                      Time.zone.now - topic.created_at
                    end
                  ) / 1.minute).round

    if num_minutes.minutes >= 2.days
      I18n.t("#{locale_key}_days", count: (num_minutes.minutes / 1.day).round)
    else
      num_hours = (num_minutes.minutes / 1.hour).round
      if num_hours >= 2
        I18n.t("#{locale_key}_hours", count: num_hours)
      else
        I18n.t("#{locale_key}_minutes", count: num_minutes)
      end
    end
  end

  def options_for(status)
    { bump: status.reopening_topic?,
      post_type: Post.types[:small_action],
      action_code: status.action_code }
  end

  Status = Struct.new(:name, :enabled) do
    %w(pinned_globally pinned autoclosed closed visible archived).each do |status|
      define_method("#{status}?") { name == status }
    end

    def enabled?
      enabled
    end

    def disabled?
      !enabled?
    end

    def action_code
      "#{name}.#{enabled? ? 'enabled' : 'disabled'}"
    end

    def locale_key
      "topic_statuses.#{action_code.gsub('.', '_')}"
    end

    def reopening_topic?
      (closed? || autoclosed?) && disabled?
    end

    def manually_closing_topic?
      closed? && enabled?
    end
  end
end
