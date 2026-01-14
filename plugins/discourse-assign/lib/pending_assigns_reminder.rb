# frozen_string_literal: true

class PendingAssignsReminder
  REMINDED_AT = "last_reminded_at"
  REMINDERS_FREQUENCY = "remind_assigns_frequency"
  CUSTOM_FIELD_NAME = "assigns_reminder"

  def remind(user)
    newest_topics = assigned_topics(user, order: :desc)
    return if newest_topics.size < SiteSetting.pending_assign_reminder_threshold

    delete_previous_reminders(user)

    oldest_topics = assigned_topics(user, order: :asc).where.not(id: newest_topics.map(&:id))
    assigned_topics_count = assigned_count_for(user)
    title = I18n.t("pending_assigns_reminder.title", pending_assignments: assigned_topics_count)

    PostCreator.create!(
      Discourse.system_user,
      title: title,
      raw: reminder_body(user, assigned_topics_count, newest_topics, oldest_topics),
      archetype: Archetype.private_message,
      subtype: TopicSubtype.system_message,
      target_usernames: user.username,
      custom_fields: {
        CUSTOM_FIELD_NAME => true,
      },
    )

    update_last_reminded(user)
  end

  private

  def delete_previous_reminders(user)
    posts =
      Post
        .joins(topic: { topic_allowed_users: :user })
        .where(
          topic: {
            posts_count: 1,
            user_id: Discourse.system_user,
            archetype: Archetype.private_message,
            subtype: TopicSubtype.system_message,
            topic_allowed_users: {
              users: {
                id: user.id,
              },
            },
          },
        )
        .joins(topic: :_custom_fields)
        .where(topic_custom_fields: { name: CUSTOM_FIELD_NAME })

    posts.find_each { |post| PostDestroyer.new(Discourse.system_user, post).destroy }
  end

  def visible_topics(user)
    Topic.listable_topics.secured(Guardian.new(user)).or(Topic.private_messages_for_user(user))
  end

  def assigned_count_for(user)
    assignments =
      Assignment
        .joins_with_topics
        .where(assigned_to_id: user.id, assigned_to_type: "User", active: true)
        .merge(visible_topics(user))
    assignments =
      DiscoursePluginRegistry.apply_modifier(:assigned_count_for_user_query, assignments, user)
    assignments.count
  end

  def assigned_topics(user, order:)
    secure = visible_topics(user)

    topics =
      Topic
        .joins(:assignment)
        .select(:slug, :id, :title, :fancy_title, "assignments.created_at AS assigned_at")
        .where(
          "assignments.assigned_to_id = ? AND assignments.assigned_to_type = 'User' AND assignments.active",
          user.id,
        )
    topics = DiscoursePluginRegistry.apply_modifier(:assigns_reminder_assigned_topics_query, topics)
    topics.merge(secure).order("assignments.created_at #{order}").limit(3)
  end

  def reminder_body(user, assigned_topics_count, first_three_topics, last_three_topics)
    newest_list = build_list_for(:newest, first_three_topics)
    oldest_list = build_list_for(:oldest, last_three_topics)

    I18n.t(
      "pending_assigns_reminder.body",
      pending_assignments: assigned_topics_count,
      assignments_link: "#{Discourse.base_url}/u/#{user.username_lower}/activity/assigned",
      newest_assignments: newest_list,
      oldest_assignments: oldest_list,
      frequency: frequency_in_words(user),
    )
  end

  def build_list_for(key, topics)
    return "" if topics.empty?
    initial_list = { "topic_0" => "", "topic_1" => "", "topic_2" => "" }
    items =
      topics
        .each_with_index
        .reduce(initial_list) do |memo, (t, index)|
          memo[
            "topic_#{index}"
          ] = "- [#{Emoji.gsub_emoji_to_unicode(t.fancy_title)}](#{t.relative_url}) - assigned #{time_in_words_for(t)}"
          memo
        end

    I18n.t("pending_assigns_reminder.#{key}", items.symbolize_keys!)
  end

  def time_in_words_for(topic)
    AgeWords.distance_of_time_in_words(
      Time.zone.now,
      topic.assigned_at.to_time,
      false,
      scope: "datetime.distance_in_words_verbose",
    )
  end

  def frequency_in_words(user)
    frequency =
      if user.custom_fields&.has_key?(REMINDERS_FREQUENCY)
        user.custom_fields[REMINDERS_FREQUENCY]
      else
        SiteSetting.remind_assigns_frequency
      end

    ::RemindAssignsFrequencySiteSettings.frequency_for(frequency)
  end

  def update_last_reminded(user)
    update_last_reminded = { REMINDED_AT => DateTime.now }
    user.upsert_custom_fields(update_last_reminded)
  end
end
