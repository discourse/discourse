module DiscourseTagging

  TAGS_FIELD_NAME = "tags"
  TAGS_FILTER_REGEXP = /[<\\\/\>\#\?\&\s]/

  # class Engine < ::Rails::Engine
  #   engine_name "discourse_tagging"
  #   isolate_namespace DiscourseTagging
  # end

  def self.tag_topic_by_names(topic, guardian, tag_names_arg)
    if SiteSetting.tagging_enabled
      tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, guardian) || []

      old_tag_names = topic.tags.map(&:name) || []
      new_tag_names = tag_names - old_tag_names
      removed_tag_names = old_tag_names - tag_names

      # Protect staff-only tags
      unless guardian.is_staff?
        staff_tags = DiscourseTagging.staff_only_tags(new_tag_names)
        if staff_tags.present?
          topic.errors[:base] << I18n.t("tags.staff_tag_disallowed", tag: staff_tags.join(" "))
          return false
        end

        staff_tags = DiscourseTagging.staff_only_tags(removed_tag_names)
        if staff_tags.present?
          topic.errors[:base] << I18n.t("tags.staff_tag_remove_disallowed", tag: staff_tags.join(" "))
          return false
        end
      end

      if tag_names.present?
        tags = Tag.where(name: tag_names).all
        if tags.size < tag_names.size
          existing_names = tags.map(&:name)
          tag_names.each do |name|
            next if existing_names.include?(name)
            tags << Tag.create(name: name)
          end
        end

        auto_notify_for(tags, topic)

        topic.tags = tags
      else
        auto_notify_for([], topic)
        topic.tags = []
      end
    end
    true
  end

  def self.auto_notify_for(tags, topic)
    TagUser.auto_watch_new_topic(topic, tags)
    TagUser.auto_track_new_topic(topic, tags)
  end

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

    return unless tags.present?

    tags.map! {|t| clean_tag(t) }
    tags.delete_if {|t| t.blank? }
    tags.uniq!

    # If the user can't create tags, remove any tags that don't already exist
    # TODO: this is doing a full count, it should just check first or use a cache
    unless guardian.can_create_tag?
      tags = Tag.where(name: tags).pluck(:name)
    end

    return tags[0...SiteSetting.max_tags_per_topic]
  end

  def self.notification_key(tag_id)
    "tags_notification:#{tag_id}"
  end

  def self.muted_tags(user)
    return [] unless user
    UserCustomField.where(user_id: user.id, value: TopicUser.notification_levels[:muted]).pluck(:name).map { |x| x[0,17] == "tags_notification" ? x[18..-1] : nil}.compact
  end
end
