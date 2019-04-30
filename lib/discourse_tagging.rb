module DiscourseTagging

  TAGS_FIELD_NAME = "tags"
  TAGS_FILTER_REGEXP = /[\/\?#\[\]@!\$&'\(\)\*\+,;=\.%\\`^\s|\{\}"<>]+/ # /?#[]@!$&'()*+,;=.%\`^|{}"<>
  TAGS_STAFF_CACHE_KEY = "staff_tag_names"

  TAG_GROUP_TAG_IDS_SQL = <<-SQL
      SELECT tag_id
        FROM tag_group_memberships tgm
  INNER JOIN tag_groups tg
          ON tgm.tag_group_id = tg.id
  SQL

  def self.tag_topic_by_names(topic, guardian, tag_names_arg, append: false)
    if guardian.can_tag?(topic)
      tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, guardian) || []

      old_tag_names = topic.tags.pluck(:name) || []
      new_tag_names = tag_names - old_tag_names
      removed_tag_names = old_tag_names - tag_names

      # Protect staff-only tags
      unless guardian.is_staff?
        all_staff_tags = DiscourseTagging.staff_tag_names
        hidden_tags = DiscourseTagging.hidden_tag_names

        staff_tags = new_tag_names & all_staff_tags
        staff_tags += new_tag_names & hidden_tags
        if staff_tags.present?
          topic.errors.add(:base, I18n.t("tags.staff_tag_disallowed", tag: staff_tags.join(" ")))
          return false
        end

        staff_tags = removed_tag_names & all_staff_tags
        if staff_tags.present?
          topic.errors.add(:base, I18n.t("tags.staff_tag_remove_disallowed", tag: staff_tags.join(" ")))
          return false
        end

        tag_names += removed_tag_names & hidden_tags
      end

      category = topic.category
      tag_names = tag_names + old_tag_names if append

      if tag_names.present?
        # guardian is explicitly nil cause we don't want to strip all
        # staff tags that already passed validation
        tags = filter_allowed_tags(
          Tag.where_name(tag_names),
          nil, # guardian
          for_topic: true,
          category: category,
          selected_tags: tag_names
        ).to_a

        if tags.size < tag_names.size && (category.nil? || (category.tags.count == 0 && category.tag_groups.count == 0))
          tag_names.each do |name|
            unless Tag.where_name(name).exists?
              tags << Tag.create(name: name)
            end
          end
        end

        # add missing mandatory parent tags
        parent_tags = TagGroup.includes(:parent_tag).where("tag_groups.id IN (
          SELECT tg.id
            FROM tag_groups tg
      INNER JOIN tag_group_memberships tgm
              ON tgm.tag_group_id = tg.id
           WHERE tg.parent_tag_id IS NOT NULL
             AND tgm.tag_id IN (?))", tags.map(&:id)).map(&:parent_tag)

        parent_tags.reject { |t| tag_names.include?(t.name) }.each do |tag|
          tags << tag
        end

        # validate minimum required tags for a category
        if !guardian.is_staff? && category && category.minimum_required_tags > 0 && tags.length < category.minimum_required_tags
          topic.errors.add(:base, I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
          return false
        end

        topic.tags = tags
      else
        # validate minimum required tags for a category
        if !guardian.is_staff? && category && category.minimum_required_tags > 0
          topic.errors.add(:base, I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
          return false
        end

        topic.tags = []
      end
      topic.tags_changed = true
    end
    true
  end

  # Options:
  #   term: a search term to filter tags by name
  #   category: a Category to which the object being tagged belongs
  #   for_input: result is for an input field, so only show permitted tags
  #   for_topic: results are for tagging a topic
  #   selected_tags: an array of tag names that are in the current selection
  def self.filter_allowed_tags(query, guardian, opts = {})
    selected_tag_ids = opts[:selected_tags] ? Tag.where_name(opts[:selected_tags]).pluck(:id) : []

    if !opts[:for_topic] && !selected_tag_ids.empty?
      query = query.where('tags.id NOT IN (?)', selected_tag_ids)
    end

    term = opts[:term]
    if term.present?
      term = term.gsub("_", "\\_")
      clean_tag(term)
      term.downcase!
      query = query.where('lower(tags.name) like ?', "%#{term}%")
    end

    # Filters for category-specific tags:
    category = opts[:category]

    if category && (category.tags.count > 0 || category.tag_groups.count > 0)
      if category.allow_global_tags
        # Select tags that:
        #   * are restricted to the given category
        #   * belong to no tag groups and aren't restricted to other categories
        #   * belong to tag groups that are not restricted to any categories
        query = query.where(<<~SQL, category.tag_groups.pluck(:id), category.id)
          tags.id IN (
            SELECT t.id FROM tags t
            LEFT JOIN category_tags ct ON t.id = ct.tag_id
            LEFT JOIN (
              SELECT xtgm.tag_id, xtgm.tag_group_id
              FROM tag_group_memberships xtgm
              INNER JOIN category_tag_groups ctg
              ON xtgm.tag_group_id = ctg.tag_group_id
            ) AS tgm ON t.id = tgm.tag_id
            WHERE (tgm.tag_group_id IS NULL AND ct.category_id IS NULL)
               OR tgm.tag_group_id IN (?)
               OR ct.category_id = ?
          )
        SQL
      else
        # Select only tags that are restricted to the given category
        query = query.where(<<~SQL, category.id, category.tag_groups.pluck(:id))
          tags.id IN (
            SELECT tag_id FROM category_tags WHERE category_id = ?
            UNION
            SELECT tag_id FROM tag_group_memberships WHERE tag_group_id IN (?)
          )
        SQL
      end
    elsif opts[:for_input] || opts[:for_topic] || category
      # exclude tags that are restricted to other categories
      if CategoryTag.exists?
        query = query.where("tags.id NOT IN (SELECT tag_id FROM category_tags)")
      end

      if CategoryTagGroup.exists?
        tag_group_ids = CategoryTagGroup.pluck(:tag_group_id).uniq
        query = query.where("tags.id NOT IN (SELECT tag_id FROM tag_group_memberships WHERE tag_group_id IN (?))", tag_group_ids)
      end
    end

    if opts[:for_input] || opts[:for_topic]
      unless guardian.nil? || guardian.is_staff?
        all_staff_tags = DiscourseTagging.staff_tag_names
        query = query.where('tags.name NOT IN (?)', all_staff_tags) if all_staff_tags.present?
      end
    end

    if opts[:for_input]
      # exclude tag groups that have a parent tag which is missing from selected_tags

      if selected_tag_ids.empty?
        sql = "tags.id NOT IN (#{TAG_GROUP_TAG_IDS_SQL} WHERE tg.parent_tag_id IS NOT NULL)"
        query = query.where(sql)
      else
        exclude_group_ids = one_per_topic_group_ids(selected_tag_ids)

        if exclude_group_ids.empty?
          sql = "tags.id NOT IN (#{TAG_GROUP_TAG_IDS_SQL} WHERE tg.parent_tag_id NOT IN (?))"
          query = query.where(sql, selected_tag_ids)
        else
          # It's possible that the selected tags violate some one-tag-per-group restrictions,
          # so filter them out by picking one from each group.
          limit_tag_ids = TagGroupMembership.select('distinct on (tag_group_id) tag_id')
            .where(tag_id: selected_tag_ids)
            .where(tag_group_id: exclude_group_ids)
            .map(&:tag_id)
          sql = "(tags.id NOT IN (#{TAG_GROUP_TAG_IDS_SQL} WHERE (tg.parent_tag_id NOT IN (?) OR tg.id in (?))) OR tags.id IN (?))"
          query = query.where(sql, selected_tag_ids, exclude_group_ids, limit_tag_ids)
        end
      end
    elsif opts[:for_topic] && !selected_tag_ids.empty?
      # One tag per group restriction
      exclude_group_ids = one_per_topic_group_ids(selected_tag_ids)

      unless exclude_group_ids.empty?
        limit_tag_ids = TagGroupMembership.select('distinct on (tag_group_id) tag_id')
          .where(tag_id: selected_tag_ids)
          .where(tag_group_id: exclude_group_ids)
          .map(&:tag_id)
        sql = "(tags.id NOT IN (#{TAG_GROUP_TAG_IDS_SQL} WHERE (tg.id in (?))) OR tags.id IN (?))"
        query = query.where(sql, exclude_group_ids, limit_tag_ids)
      end
    end

    if guardian.nil? || guardian.is_staff?
      query
    else
      filter_visible(query, guardian)
    end
  end

  def self.one_per_topic_group_ids(selected_tag_ids)
    TagGroup.where(one_per_topic: true)
      .joins(:tag_group_memberships)
      .where('tag_group_memberships.tag_id in (?)', selected_tag_ids)
      .pluck(:id)
  end

  def self.filter_visible(query, guardian = nil)
    guardian&.is_staff? ? query : query.where("tags.id NOT IN (#{hidden_tags_query.select(:id).to_sql})")
  end

  def self.hidden_tag_names(guardian = nil)
    guardian&.is_staff? ? [] : hidden_tags_query.pluck(:name)
  end

  def self.hidden_tags_query
    Tag.joins(:tag_groups)
      .where('tag_groups.id NOT IN (
        SELECT tag_group_id
        FROM tag_group_permissions
        WHERE group_id = ?)',
        Group::AUTO_GROUPS[:everyone]
      )
  end

  def self.staff_tag_names
    tag_names = Discourse.cache.read(TAGS_STAFF_CACHE_KEY, tag_names)

    if !tag_names
      tag_names = Tag.joins(tag_groups: :tag_group_permissions)
        .where('tag_group_permissions.group_id = ? AND tag_group_permissions.permission_type = ?',
          Group::AUTO_GROUPS[:everyone],
          TagGroupPermission.permission_types[:readonly]
        ).pluck(:name)
      Discourse.cache.write(TAGS_STAFF_CACHE_KEY, tag_names, expires_in: 1.hour)
    end

    tag_names
  end

  def self.clear_cache!
    Discourse.cache.delete(TAGS_STAFF_CACHE_KEY)
  end

  def self.clean_tag(tag)
    tag = tag.dup
    tag.downcase! if SiteSetting.force_lowercase_tags
    tag.strip!
    tag.gsub!(/\s+/, '-')
    tag.squeeze!('-')
    tag.gsub!(TAGS_FILTER_REGEXP, '')
    tag[0...SiteSetting.max_tag_length]
  end

  def self.tags_for_saving(tags_arg, guardian, opts = {})

    return [] unless guardian.can_tag_topics? && tags_arg.present?

    tag_names = Tag.where_name(tags_arg).pluck(:name)

    if guardian.can_create_tag?
      tag_names += (tags_arg - tag_names).map { |t| clean_tag(t) }
      tag_names.delete_if { |t| t.blank? }
      tag_names.uniq!
    end

    return opts[:unlimited] ? tag_names : tag_names[0...SiteSetting.max_tags_per_topic]
  end

  def self.add_or_create_tags_by_name(taggable, tag_names_arg, opts = {})
    tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, Guardian.new(Discourse.system_user), opts) || []
    if taggable.tags.pluck(:name).sort != tag_names.sort
      taggable.tags = Tag.where_name(tag_names).all
      if taggable.tags.size < tag_names.size
        new_tag_names = tag_names - taggable.tags.map(&:name)
        new_tag_names.each do |name|
          taggable.tags << Tag.create(name: name)
        end
      end
    end
  end

  def self.muted_tags(user)
    return [] unless user
    TagUser.lookup(user, :muted).joins(:tag).pluck('tags.name')
  end
end
