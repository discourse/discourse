TopicStatusUpdate = Struct.new(:topic, :user) do
  def update!(status, enabled)
    status = Status.new(status, enabled)

    Topic.transaction do
      change status
      create_moderator_post_for status
    end
  end

  private

  def change(status)
    if status.pinned?
      topic.update_pinned status.enabled?
    elsif status.autoclosed?
      topic.update_column 'closed', status.enabled?
    else
      topic.update_column status.name, status.enabled?
    end
  end

  def create_moderator_post_for(status)
    topic.add_moderator_post(user, message_for(status), options_for(status))
  end

  def message_for(status)
    if status.autoclosed?
      num_days = topic.auto_close_started_at ? ((Time.zone.now - topic.auto_close_started_at) / 1.day).round : topic.age_in_days
      I18n.t status.locale_key, count: num_days
    else
      I18n.t status.locale_key
    end
  end

  def options_for(status)
    { bump: status.reopening_topic? }
  end

  Status = Struct.new(:name, :enabled) do
    %w(pinned autoclosed closed).each do |status|
      define_method("#{status}?") { name == status }
    end

    def enabled?
      enabled
    end

    def disabled?
      !enabled?
    end

    def locale_key
      "topic_statuses.#{name}_#{enabled? ? 'enabled' : 'disabled'}"
    end

    def reopening_topic?
      (closed? || autoclosed?) && disabled?
    end
  end
end
