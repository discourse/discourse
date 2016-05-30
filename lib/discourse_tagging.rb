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
        category = topic.category
        tags = filter_allowed_tags(Tag.where(name: tag_names), guardian, { for_input: true, category: category }).to_a

        if tags.size < tag_names.size && (category.nil? || category.tags.count == 0)
          tag_names.each do |name|
            unless Tag.where(name: name).exists?
              tags << Tag.create(name: name)
            end
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

  # Options:
  #   term: a search term to filter tags by name
  #   for_input: result is for an input field, so only show permitted tags
  #   category: a Category to which the object being tagged belongs
  def self.filter_allowed_tags(query, guardian, opts={})
    term = opts[:term]
    if term.present?
      term.gsub!(/[^a-z0-9\.\-\_]*/, '')
      term.gsub!("_", "\\_")
      query = query.where('tags.name like ?', "%#{term}%")
    end

    if opts[:for_input]
      unless guardian.is_staff?
        staff_tag_names = SiteSetting.staff_tags.split("|")
        query = query.where('tags.name NOT IN (?)', staff_tag_names) if staff_tag_names.present?
      end

      if opts[:category] && opts[:category].tags.count > 0
        query = query.where("tags.id IN (SELECT tag_id FROM category_tags WHERE category_id = ?)", opts[:category].id)
      elsif CategoryTag.exists?
        query = query.where("tags.id NOT IN (SELECT tag_id FROM category_tags)")
      end
    end

    query
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

    tag_names = tags.map {|t| clean_tag(t) }
    tag_names.delete_if {|t| t.blank? }
    tag_names.uniq!

    # If the user can't create tags, remove any tags that don't already exist
    unless guardian.can_create_tag?
      tag_names = Tag.where(name: tag_names).pluck(:name)
    end

    return tag_names[0...SiteSetting.max_tags_per_topic]
  end

  def self.notification_key(tag_id)
    "tags_notification:#{tag_id}"
  end

  def self.muted_tags(user)
    return [] unless user
    UserCustomField.where(user_id: user.id, value: TopicUser.notification_levels[:muted]).pluck(:name).map { |x| x[0,17] == "tags_notification" ? x[18..-1] : nil}.compact
  end
end
