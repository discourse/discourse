# frozen_string_literal: true

class DismissTopics
  def initialize(user, topics_scope)
    @user = user
    @topics_scope = topics_scope
  end

  def perform!
    DismissedTopicUser.insert_all(rows) if rows.present?
  end

  private

  def rows
    @rows ||= @topics_scope.where("topics.created_at >= ?", since_date).order("topics.created_at DESC").limit(SiteSetting.max_new_topics).map do |topic|
      {
        topic_id: topic.id,
        user_id: @user.id,
        created_at: Time.zone.now
      }
    end
  end

  def since_date
    new_topic_duration_minutes = @user.user_option&.new_topic_duration_minutes || SiteSetting.default_other_new_topic_duration_minutes
    setting_date =
      case new_topic_duration_minutes
      when User::NewTopicDuration::LAST_VISIT
        @user.previous_visit_at || @user.created_at
      when User::NewTopicDuration::ALWAYS
        @user.created_at
      else
        new_topic_duration_minutes.minutes.ago
      end
    [setting_date, @user.user_stat.new_since, Time.at(SiteSetting.min_new_topics_time).to_datetime].max
  end
end
