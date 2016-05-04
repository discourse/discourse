module DiscourseTagging

  TAGS_FIELD_NAME = "tags"
  TAGS_FILTER_REGEXP = /[<\\\/\>\#\?\&\s]/

  # class Engine < ::Rails::Engine
  #   engine_name "discourse_tagging"
  #   isolate_namespace DiscourseTagging
  # end

  def self.clean_tag(tag)
    tag.downcase.strip[0...SiteSetting.max_tag_length].gsub(TAGS_FILTER_REGEXP, '')
  end

  def self.staff_only_tags(tags)
    return nil if tags.nil?

    staff_tags = SiteSetting.staff_tags.split("|")

    tag_diff = tags - staff_tags
    tag_diff = tags - tag_diff

    tag_diff.present? ? tag_diff : nil
  end

  def self.tags_for_saving(tags, guardian)

    return [] unless guardian.can_tag_topics?

    return unless tags

    tags.map! {|t| clean_tag(t) }
    tags.delete_if {|t| t.blank? }
    tags.uniq!

    # If the user can't create tags, remove any tags that don't already exist
    # TODO: this is doing a full count, it should just check first or use a cache
    unless guardian.can_create_tag?
      tag_count = TopicCustomField.where(name: TAGS_FIELD_NAME, value: tags).group(:value).count
      tags.delete_if {|t| !tag_count.has_key?(t) }
    end

    return tags[0...SiteSetting.max_tags_per_topic]
  end

  def self.notification_key(tag_id)
    "tags_notification:#{tag_id}"
  end

  def self.auto_notify_for(tags, topic)
    # This insert will run up to SiteSetting.max_tags_per_topic times
    tags.each do |tag|
      key_name_sql = ActiveRecord::Base.sql_fragment("('#{notification_key(tag)}')", tag)

      sql = <<-SQL
         INSERT INTO topic_users(user_id, topic_id, notification_level, notifications_reason_id)
         SELECT ucf.user_id,
                #{topic.id.to_i},
                CAST(ucf.value AS INTEGER),
                #{TopicUser.notification_reasons[:plugin_changed]}
         FROM user_custom_fields AS ucf
         WHERE ucf.name IN #{key_name_sql}
           AND NOT EXISTS(SELECT 1 FROM topic_users WHERE topic_id = #{topic.id.to_i} AND user_id = ucf.user_id)
           AND CAST(ucf.value AS INTEGER) <> #{TopicUser.notification_levels[:regular]}
      SQL

      ActiveRecord::Base.exec_sql(sql)
    end
  end

  def self.rename_tag(current_user, old_id, new_id)
    sql = <<-SQL
      UPDATE topic_custom_fields AS tcf
        SET value = :new_id
      WHERE value = :old_id
        AND name = :tags_field_name
        AND NOT EXISTS(SELECT 1
                       FROM topic_custom_fields
                       WHERE value = :new_id AND name = :tags_field_name AND topic_id = tcf.topic_id)
    SQL

    user_sql = <<-SQL
      UPDATE user_custom_fields
        SET name = :new_user_tag_id
      WHERE name = :old_user_tag_id
        AND NOT EXISTS(SELECT 1
                       FROM user_custom_fields
                       WHERE name = :new_user_tag_id)
    SQL

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.exec_sql(sql, new_id: new_id, old_id: old_id, tags_field_name: TAGS_FIELD_NAME)
      TopicCustomField.delete_all(name: TAGS_FIELD_NAME, value: old_id)
      ActiveRecord::Base.exec_sql(user_sql, new_user_tag_id: notification_key(new_id),
                                       old_user_tag_id: notification_key(old_id))
      UserCustomField.delete_all(name: notification_key(old_id))
      StaffActionLogger.new(current_user).log_custom('renamed_tag', previous_value: old_id, new_value: new_id)
    end
  end

  def self.top_tags(limit_arg=nil)
    # TODO: cache
    # TODO: need an index for this (name,value)
    TopicCustomField.where(name: TAGS_FIELD_NAME)
                    .group(:value)
                    .limit(limit_arg || SiteSetting.max_tags_in_filter_list)
                    .order('COUNT(value) DESC')
                    .count
                    .map {|name, count| name}
  end

  def self.muted_tags(user)
    return [] unless user
    UserCustomField.where(user_id: user.id, value: TopicUser.notification_levels[:muted]).pluck(:name).map { |x| x[0,17] == "tags_notification" ? x[18..-1] : nil}.compact
  end
end
