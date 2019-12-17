# frozen_string_literal: true

module DiscourseTagging

  TAGS_FIELD_NAME ||= "tags"
  TAGS_FILTER_REGEXP ||= /[\/\?#\[\]@!\$&'\(\)\*\+,;=\.%\\`^\s|\{\}"<>]+/ # /?#[]@!$&'()*+,;=.%\`^|{}"<>
  TAGS_STAFF_CACHE_KEY ||= "staff_tag_names"

  TAG_GROUP_TAG_IDS_SQL ||= <<-SQL
      SELECT tag_id
        FROM tag_group_memberships tgm
  INNER JOIN tag_groups tg
          ON tgm.tag_group_id = tg.id
  SQL

  def self.tag_topic_by_names(topic, guardian, tag_names_arg, append: false)
    if guardian.can_tag?(topic)
      tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, guardian) || []

      if !tag_names.empty?
        Tag.where_name(tag_names).joins(:target_tag).includes(:target_tag).each do |tag|
          tag_names[tag_names.index(tag.name)] = tag.target_tag.name
        end
      end

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
          nil, # guardian
          for_topic: true,
          category: category,
          selected_tags: tag_names,
          only_tag_names: tag_names
        )

        tags = Tag.where(id: tags.map(&:id)).all.to_a if tags.size > 0

        if tags.size < tag_names.size && (category.nil? || category.allow_global_tags || (category.tags.count == 0 && category.tag_groups.count == 0))
          tag_names.each do |name|
            unless Tag.where_name(name).exists?
              tags << Tag.create(name: name)
            end
          end
        end

        # add missing mandatory parent tags
        tag_ids = tags.map(&:id)

        parent_tags_map = DB.query("
          SELECT tgm.tag_id, tg.parent_tag_id
            FROM tag_groups tg
      INNER JOIN tag_group_memberships tgm
              ON tgm.tag_group_id = tg.id
           WHERE tg.parent_tag_id IS NOT NULL
             AND tgm.tag_id IN (?)
        ", tag_ids).inject({}) do |h, v|
          h[v.tag_id] ||= []
          h[v.tag_id] << v.parent_tag_id
          h
        end

        missing_parent_tag_ids = parent_tags_map.map do |_, parent_tag_ids|
          (tag_ids & parent_tag_ids).size == 0 ? parent_tag_ids.first : nil
        end.compact.uniq

        unless missing_parent_tag_ids.empty?
          tags = tags + Tag.where(id: missing_parent_tag_ids).all
        end

        return false unless validate_min_required_tags_for_category(guardian, topic, category, tags)
        return false unless validate_required_tags_from_group(guardian, topic, category, tags)

        if tags.size == 0
          topic.errors.add(:base, I18n.t("tags.forbidden.invalid", count: new_tag_names.size))
          return false
        end

        topic.tags = tags
      else
        return false unless validate_min_required_tags_for_category(guardian, topic, category)
        return false unless validate_required_tags_from_group(guardian, topic, category)

        topic.tags = []
      end
      topic.tags_changed = true
    end
    true
  end

  def self.validate_min_required_tags_for_category(guardian, topic, category, tags = [])
    if !guardian.is_staff? &&
        category &&
        category.minimum_required_tags > 0 &&
        tags.length < category.minimum_required_tags

      topic.errors.add(:base, I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
      false
    else
      true
    end
  end

  def self.validate_required_tags_from_group(guardian, topic, category, tags = [])
    if !guardian.is_staff? &&
        category &&
        category.required_tag_group &&
        (tags.length < category.min_tags_from_required_group ||
          category.required_tag_group.tags.where("tags.id in (?)", tags.map(&:id)).count < category.min_tags_from_required_group)

      topic.errors.add(:base,
        I18n.t(
          "tags.required_tags_from_group",
          count: category.min_tags_from_required_group,
          tag_group_name: category.required_tag_group.name
        )
      )
      false
    else
      true
    end
  end

  TAG_GROUP_RESTRICTIONS_SQL ||= <<~SQL
    tag_group_restrictions AS (
      SELECT t.id as tag_id, tgm.id as tgm_id, tg.id as tag_group_id, tg.parent_tag_id as parent_tag_id,
        tg.one_per_topic as one_per_topic
      FROM tags t
      LEFT OUTER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      LEFT OUTER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
    )
  SQL

  CATEGORY_RESTRICTIONS_SQL ||= <<~SQL
    category_restrictions AS (
      SELECT t.id as tag_id, ct.id as ct_id, ct.category_id as category_id
      FROM tags t
      INNER JOIN category_tags ct ON t.id = ct.tag_id /*and_name_like*/

      UNION

      SELECT t.id as tag_id, ctg.id as ctg_id, ctg.category_id as category_id
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN category_tag_groups ctg ON tgm.tag_group_id = ctg.tag_group_id
    )
  SQL

  PERMITTED_TAGS_SQL ||= <<~SQL
    permitted_tag_groups AS (
      SELECT tg.id as tag_group_id, tgp.group_id as group_id, tgp.permission_type as permission_type
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
      INNER JOIN tag_group_permissions tgp
      ON tg.id = tgp.tag_group_id
      AND tgp.group_id = #{Group::AUTO_GROUPS[:everyone]}
      AND tgp.permission_type = #{TagGroupPermission.permission_types[:full]}
    )
  SQL

  # Options:
  #   term: a search term to filter tags by name
  #   limit: max number of results
  #   category: a Category to which the object being tagged belongs
  #   for_input: result is for an input field, so only show permitted tags
  #   for_topic: results are for tagging a topic
  #   selected_tags: an array of tag names that are in the current selection
  #   only_tag_names: limit results to tags with these names
  #   exclude_synonyms: exclude synonyms from results
  #   order_search_results: result should be ordered for name search results
  #   order_popularity: order result by topic_count
  def self.filter_allowed_tags(guardian, opts = {})
    selected_tag_ids = opts[:selected_tags] ? Tag.where_name(opts[:selected_tags]).pluck(:id) : []
    category = opts[:category]
    category_has_restricted_tags = category ? (category.tags.count > 0 || category.tag_groups.count > 0) : false

    # If guardian is nil, it means the caller doesn't want tags to be filtered
    # based on guardian rules. Use the same rules as for staff users.
    filter_for_non_staff = !guardian.nil? && !guardian.is_staff?

    builder_params = {}

    unless selected_tag_ids.empty?
      builder_params[:selected_tag_ids] = selected_tag_ids
    end

    sql = +"WITH #{TAG_GROUP_RESTRICTIONS_SQL}, #{CATEGORY_RESTRICTIONS_SQL}"
    if (opts[:for_input] || opts[:for_topic]) && filter_for_non_staff
      sql << ", #{PERMITTED_TAGS_SQL} "
    end

    outer_join = category.nil? || category.allow_global_tags || !category_has_restricted_tags

    distinct_clause = if opts[:order_popularity]
      "DISTINCT ON (topic_count, name)"
    elsif opts[:order_search_results] && opts[:term].present?
      "DISTINCT ON (lower(name) = lower(:cleaned_term), topic_count, name)"
    else
      ""
    end

    sql << <<~SQL
      SELECT #{distinct_clause} t.id, t.name, t.topic_count, t.pm_topic_count,
        tgr.tgm_id as tgm_id, tgr.tag_group_id as tag_group_id, tgr.parent_tag_id as parent_tag_id,
        tgr.one_per_topic as one_per_topic, t.target_tag_id
      FROM tags t
      INNER JOIN tag_group_restrictions tgr ON tgr.tag_id = t.id
      #{outer_join ? "LEFT OUTER" : "INNER"}
        JOIN category_restrictions cr ON t.id = cr.tag_id
      /*where*/
      /*order_by*/
      /*limit*/
    SQL

    builder = DB.build(sql)

    if !opts[:for_topic] && builder_params[:selected_tag_ids]
      builder.where("id NOT IN (:selected_tag_ids)")
    end

    if opts[:only_tag_names]
      builder.where("LOWER(name) IN (:only_tag_names)")
      builder_params[:only_tag_names] = opts[:only_tag_names].map(&:downcase)
    end

    # parent tag requirements
    if opts[:for_input]
      builder.where(
        builder_params[:selected_tag_ids] ?
          "tgm_id IS NULL OR parent_tag_id IS NULL OR parent_tag_id IN (:selected_tag_ids)" :
          "tgm_id IS NULL OR parent_tag_id IS NULL"
      )
    end

    if category && category_has_restricted_tags
      builder.where(
        category.allow_global_tags ? "category_id = ? OR category_id IS NULL" : "category_id = ?",
        category.id
      )
    elsif category || opts[:for_input] || opts[:for_topic]
      # tags not restricted to any categories
      builder.where("category_id IS NULL")
    end

    if filter_for_non_staff && (opts[:for_input] || opts[:for_topic])
      # exclude staff-only tag groups
      builder.where("tag_group_id IS NULL OR tag_group_id IN (SELECT tag_group_id FROM permitted_tag_groups)")
    end

    term = opts[:term]
    if term.present?
      term = term.gsub("_", "\\_").downcase
      builder.where("LOWER(name) LIKE :term")
      builder_params[:cleaned_term] = term
      builder_params[:term] = "%#{term}%"
      sql.gsub!("/*and_name_like*/", "AND LOWER(t.name) LIKE :term")
    else
      sql.gsub!("/*and_name_like*/", "")
    end

    if opts[:for_input] && filter_for_non_staff && category&.required_tag_group
      required_tag_ids = category.required_tag_group.tags.pluck(:id)
      if (required_tag_ids & selected_tag_ids).size < category.min_tags_from_required_group
        builder.where("id IN (?)", required_tag_ids)
      end
    end

    if filter_for_non_staff
      # remove hidden tags
      builder.where(<<~SQL, Group::AUTO_GROUPS[:everyone])
        id NOT IN (
          SELECT tag_id
            FROM tag_group_memberships tgm
           WHERE tag_group_id NOT IN (SELECT tag_group_id FROM tag_group_permissions WHERE group_id = ?)
        )
      SQL
    end

    if builder_params[:selected_tag_ids] && (opts[:for_input] || opts[:for_topic])
      one_tag_per_group_ids = DB.query(<<~SQL, builder_params[:selected_tag_ids]).map(&:id)
        SELECT DISTINCT(tg.id)
          FROM tag_groups tg
        INNER JOIN tag_group_memberships tgm ON tg.id = tgm.tag_group_id AND tgm.tag_id IN (?)
         WHERE tg.one_per_topic
      SQL

      if !one_tag_per_group_ids.empty?
        builder.where(
          "tag_group_id IS NULL OR tag_group_id NOT IN (?) OR id IN (:selected_tag_ids)",
          one_tag_per_group_ids
        )
      end
    end

    if opts[:exclude_synonyms]
      builder.where("target_tag_id IS NULL")
    end

    if opts[:exclude_has_synonyms]
      builder.where("id NOT IN (SELECT target_tag_id FROM tags WHERE target_tag_id IS NOT NULL)")
    end

    builder.limit(opts[:limit]) if opts[:limit]
    if opts[:order_popularity]
      builder.order_by("topic_count DESC, name")
    elsif opts[:order_search_results] && !term.blank?
      builder.order_by("lower(name) = lower(:cleaned_term) DESC, topic_count DESC, name")
    end

    result = builder.query(builder_params).uniq { |t| t.id }
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
    tag_names = Discourse.cache.read(TAGS_STAFF_CACHE_KEY)

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

    opts[:unlimited] ? tag_names : tag_names[0...SiteSetting.max_tags_per_topic]
  end

  def self.add_or_create_tags_by_name(taggable, tag_names_arg, opts = {})
    tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, Guardian.new(Discourse.system_user), opts) || []
    if taggable.tags.pluck(:name).sort != tag_names.sort
      taggable.tags = Tag.where_name(tag_names).all
      new_tag_names = taggable.tags.size < tag_names.size ? tag_names - taggable.tags.map(&:name) : []
      taggable.tags << Tag.where(target_tag_id: taggable.tags.map(&:id)).all
      new_tag_names.each do |name|
        taggable.tags << Tag.create(name: name)
      end
    end
  end

  # Returns true if all were added successfully, or an Array of the
  # tags that failed to be added, with errors on each Tag.
  def self.add_or_create_synonyms_by_name(target_tag, synonym_names)
    tag_names = DiscourseTagging.tags_for_saving(synonym_names, Guardian.new(Discourse.system_user)) || []
    existing = Tag.where_name(tag_names).all
    target_tag.synonyms << existing
    (tag_names - target_tag.synonyms.map(&:name)).each do |name|
      target_tag.synonyms << Tag.create(name: name)
    end
    successful = existing.select { |t| !t.errors.present? }
    TopicTag.where(tag_id: successful.map(&:id)).update_all(tag_id: target_tag.id)
    (existing - successful).presence || true
  end

  def self.muted_tags(user)
    return [] unless user
    TagUser.lookup(user, :muted).joins(:tag).pluck('tags.name')
  end
end
