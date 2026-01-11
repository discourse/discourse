# frozen_string_literal: true

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

  def self.term_types
    @term_types ||= Enum.new(contains: 0, starts_with: 1)
  end

  def self.tag_topic_by_names(topic, guardian, tag_names_arg, append: false)
    if guardian.can_tag?(topic)
      tag_names = DiscourseTagging.tags_for_saving(tag_names_arg, guardian) || []

      if !tag_names.empty?
        Tag
          .where_name(tag_names)
          .joins(:target_tag)
          .includes(:target_tag)
          .each { |tag| tag_names[tag_names.index(tag.name)] = tag.target_tag.name }
      end

      # tags currently on the topic
      old_tag_names = topic.tags.pluck(:name) || []
      # tags we're trying to add to the topic
      new_tag_names = tag_names - old_tag_names
      # tag names being removed from the topic
      removed_tag_names = old_tag_names - tag_names

      # tag names which are visible, but not usable, by *some users*
      readonly_tags = DiscourseTagging.readonly_tag_names(guardian)
      # tags names which are not visible or usable by this user
      hidden_tags = DiscourseTagging.hidden_tag_names(guardian)

      # tag names which ARE permitted by *this user*
      permitted_tags = DiscourseTagging.permitted_tag_names(guardian)

      # If this user has explicit permission to use certain tags,
      # we need to ensure those tags are removed from the list of
      # restricted tags
      readonly_tags = readonly_tags - permitted_tags if permitted_tags.present?

      # visible, but not usable, tags this user is trying to use
      disallowed_tags = new_tag_names & readonly_tags
      # hidden tags this user is trying to use
      disallowed_tags += new_tag_names & hidden_tags

      if disallowed_tags.present?
        topic.errors.add(
          :base,
          I18n.t("tags.restricted_tag_disallowed", tag: disallowed_tags.join(" ")),
        )
        return false
      end

      removed_readonly_tags = removed_tag_names & readonly_tags
      if removed_readonly_tags.present?
        topic.errors.add(
          :base,
          I18n.t("tags.restricted_tag_remove_disallowed", tag: removed_readonly_tags.join(" ")),
        )
        return false
      end

      tag_names += removed_tag_names & hidden_tags

      category = topic.category
      tag_names = tag_names + old_tag_names if append

      if tag_names.present?
        # guardian is explicitly nil cause we don't want to strip all
        # staff tags that already passed validation
        tags =
          filter_allowed_tags(
            nil, # guardian
            for_topic: true,
            category: category,
            selected_tags: tag_names,
            only_tag_names: tag_names,
          )

        # keep existent tags that current user cannot use
        tags += Tag.where(name: old_tag_names & tag_names)

        tags = Tag.where(id: tags.map(&:id)).all.to_a if tags.size > 0

        if tags.size < tag_names.size &&
             (
               category.nil? || category.allow_global_tags ||
                 (category.tags.count == 0 && category.tag_groups.count == 0)
             )
          tag_names.each do |name|
            tags << Tag.create(name: name) unless Tag.where_name(name).exists?
          end
        end

        # tests if there are conflicts between tags on tag groups that only allow one tag from the group before adding
        # mandatory parent tags because later we want to test if the mandatory parent tags introduce any conflicts
        # and be able to pinpoint the tag that is introducing it
        # guardian like above is nil to prevent stripping tags that already passed validation
        return false unless validate_one_tag_from_group_per_topic(nil, topic, category, tags)

        # add missing mandatory parent tags
        tag_ids = tags.map(&:id)

        parent_tags_sql =
          +"
          SELECT tgm.tag_id, tg.parent_tag_id
            FROM tag_groups tg
          INNER JOIN tag_group_memberships tgm
              ON tgm.tag_group_id = tg.id
           WHERE tg.parent_tag_id IS NOT NULL
             AND tgm.tag_id IN (:tag_ids)
        "

        query_params = { tag_ids: }

        if category
          if category.has_restricted_tags?
            if category.allow_global_tags
              # include parent tags from tag groups that are not restricted to any category
              # AND tag groups restricted to the current category
              parent_tags_sql << "
                 AND (
                   tg.id NOT IN (SELECT tag_group_id FROM category_tag_groups)
                   OR tg.id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id = :category_id)
                 )
              "
            else
              # only include parent tags from tag groups restricted to the current category
              parent_tags_sql << "
                 AND tg.id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id = :category_id)
              "
            end
            query_params[:category_id] = category.id
          else
            # category has no tag restrictions,
            # so only include parent tags from tag groups not restricted to any category
            parent_tags_sql << "
               AND tg.id NOT IN (SELECT tag_group_id FROM category_tag_groups)
            "
          end
        end

        parent_tags_map =
          DB
            .query(parent_tags_sql, query_params)
            .inject({}) do |h, v|
              h[v.tag_id] ||= []
              h[v.tag_id] << v.parent_tag_id
              h
            end

        missing_parent_tag_ids =
          parent_tags_map
            .map do |_, parent_tag_ids|
              (tag_ids & parent_tag_ids).size == 0 ? parent_tag_ids.first : nil
            end
            .compact
            .uniq

        missing_parent_tags = Tag.where(id: missing_parent_tag_ids).all

        tags = tags + missing_parent_tags unless missing_parent_tags.empty?

        parent_tag_conflicts =
          filter_tags_violating_one_tag_from_group_per_topic(
            nil, # guardian like above is nil to prevent stripping tags that already passed validation
            topic.category,
            tags,
          )

        if parent_tag_conflicts.present?
          # we need to get the original tag names that introduced conflicting missing parent tags to return an useful
          # error message
          parent_child_names_map = {}
          parent_tags_map.each do |tag_id, parent_tag_ids|
            next if (tag_ids & parent_tag_ids).size > 0 # tag already has a parent tag

            parent_tag = tags.select { |t| t.id == parent_tag_ids.first }.first
            original_child_tag = tags.select { |t| t.id == tag_id }.first

            next if parent_tag.blank? || original_child_tag.blank?
            parent_child_names_map[parent_tag.name] = original_child_tag.name
          end

          # replaces the added missing parent tags with the original tag
          parent_tag_conflicts.map do |_, conflicting_tags|
            topic.errors.add(
              :base,
              I18n.t(
                "tags.limited_to_one_tag_from_group",
                tags:
                  conflicting_tags
                    .map do |tag|
                      tag_name = tag.name

                      parent_child_names_map[tag_name].presence || tag_name
                    end
                    .uniq
                    .sort
                    .join(", "),
              ),
            )
          end

          return false
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

      DiscourseEvent.trigger(
        :topic_tags_changed,
        topic,
        old_tag_names: old_tag_names,
        new_tag_names: topic.tags.map(&:name),
        user: guardian.user,
      )

      true
    else
      topic.errors.add(:base, I18n.t("tags.user_not_permitted"))
      false
    end
  end

  def self.tag_topic_by_ids(topic, guardian, tag_ids, append: false)
    tag_names = Tag.where(id: tag_ids).pluck(:name)
    tag_topic_by_names(topic, guardian, tag_names, append: append)
  end

  def self.validate_category_tags(guardian, model, category, tags = [])
    existing_tags = tags.present? ? Tag.where(name: tags) : []
    valid_tags = guardian.can_create_tag? ? tags : existing_tags

    # all add to model (topic) errors
    valid = validate_min_required_tags_for_category(guardian, model, category, valid_tags)
    valid &&= validate_required_tags_from_group(guardian, model, category, existing_tags)
    valid &&= validate_category_restricted_tags(guardian, model, category, valid_tags)
    valid &&= validate_one_tag_from_group_per_topic(guardian, model, category, valid_tags)

    valid
  end

  def self.validate_min_required_tags_for_category(guardian, model, category, tags = [])
    if !guardian.is_staff? && category && category.minimum_required_tags > 0 &&
         tags.length < category.minimum_required_tags
      model.errors.add(
        :base,
        I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags),
      )
      false
    else
      true
    end
  end

  def self.validate_required_tags_from_group(guardian, model, category, tags = [])
    return true if guardian.is_staff? || category.nil?

    success = true
    category.category_required_tag_groups.each do |crtg|
      if tags.length < crtg.min_count ||
           crtg.tag_group.tags.where("tags.id in (?)", tags.map(&:id)).count < crtg.min_count
        success = false

        model.errors.add(
          :base,
          I18n.t(
            "tags.required_tags_from_group",
            count: crtg.min_count,
            tag_group_name: crtg.tag_group.name,
            tags: crtg.tag_group.tags.order(:id).pluck(:name).join(", "),
          ),
        )
      end
    end

    success
  end

  def self.validate_category_restricted_tags(guardian, model, category, tags = [])
    return true if tags.blank? || category.blank?

    tags = tags.map(&:name) if Tag === tags[0]
    tags_restricted_to_categories = Hash.new { |h, k| h[k] = Set.new }

    query = Tag.where(name: tags)
    query
      .joins(tag_groups: :categories)
      .pluck(:name, "categories.id")
      .each { |(tag, cat_id)| tags_restricted_to_categories[tag] << cat_id }
    query
      .joins(:categories)
      .pluck(:name, "categories.id")
      .each { |(tag, cat_id)| tags_restricted_to_categories[tag] << cat_id }

    unallowed_tags =
      tags_restricted_to_categories.keys.select do |tag|
        !tags_restricted_to_categories[tag].include?(category.id)
      end

    if unallowed_tags.present?
      msg =
        I18n.t(
          "tags.forbidden.restricted_tags_cannot_be_used_in_category",
          count: unallowed_tags.size,
          tags: unallowed_tags.sort.join(", "),
          category: category.name,
        )
      model.errors.add(:base, msg)
      return false
    end

    if !category.allow_global_tags && category.has_restricted_tags?
      unrestricted_tags = tags - tags_restricted_to_categories.keys
      if unrestricted_tags.present?
        msg =
          I18n.t(
            "tags.forbidden.category_does_not_allow_tags",
            count: unrestricted_tags.size,
            tags: unrestricted_tags.sort.join(", "),
            category: category.name,
          )
        model.errors.add(:base, msg)
        return false
      end
    end
    true
  end

  def self.validate_one_tag_from_group_per_topic(guardian, model, category, tags = [])
    tags_cant_be_used = filter_tags_violating_one_tag_from_group_per_topic(guardian, category, tags)

    return true if tags_cant_be_used.blank?

    tags_cant_be_used.each do |_, incompatible_tags|
      model.errors.add(
        :base,
        I18n.t(
          "tags.limited_to_one_tag_from_group",
          tags: incompatible_tags.map(&:name).sort.join(", "),
        ),
      )
    end

    false
  end

  def self.filter_tags_violating_one_tag_from_group_per_topic(guardian, category, tags = [])
    return [] if tags.size < 2

    # ensures that tags are a list of tag names
    tags = tags.map(&:name) if Tag === tags[0]

    allowed_tags =
      filter_allowed_tags(
        guardian,
        category: category,
        only_tag_names: tags,
        for_topic: true,
        order_search_results: true,
      )

    return {} if allowed_tags.size < 2

    tags_by_group_map =
      allowed_tags
        .sort_by { |tag| [tag.tag_group_id || -1, tag.name] }
        .inject({}) do |hash, tag|
          next hash unless tag.one_per_topic

          hash[tag.tag_group_id] = (hash[tag.tag_group_id] || []) << tag
          hash
        end

    tags_by_group_map.select { |_, group_tags| group_tags.size > 1 }
  end

  TAG_GROUP_RESTRICTIONS_SQL = <<~SQL
    tag_group_restrictions AS (
      SELECT t.id as tag_id, tgm.id as tgm_id, tg.id as tag_group_id, tg.parent_tag_id as parent_tag_id,
        tg.one_per_topic as one_per_topic
      FROM tags t
      LEFT OUTER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      LEFT OUTER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
    )
  SQL

  CATEGORY_RESTRICTIONS_SQL = <<~SQL
    category_restrictions AS (
      SELECT t.id as tag_id, ct.id as ct_id, ct.category_id as category_id, NULL AS category_tag_group_id
      FROM tags t
      INNER JOIN category_tags ct ON t.id = ct.tag_id /*and_name_like*/

      UNION

      SELECT t.id as tag_id, ctg.id as ctg_id, ctg.category_id as category_id, ctg.tag_group_id AS category_tag_group_id
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN category_tag_groups ctg ON tgm.tag_group_id = ctg.tag_group_id
    )
  SQL

  PERMITTED_TAGS_SQL = <<~SQL
    permitted_tag_groups AS (
      SELECT tg.id as tag_group_id, tgp.group_id as group_id, tgp.permission_type as permission_type
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
      INNER JOIN tag_group_permissions tgp
      ON tg.id = tgp.tag_group_id /*and_group_ids*/
      AND tgp.permission_type = #{TagGroupPermission.permission_types[:full]}
    )
  SQL

  # Options:
  #   term: a search term to filter tags by name
  #   term_type: whether to search by "starts_with" or "contains" with the term
  #   limit: max number of results
  #   category: a Category to which the object being tagged belongs
  #   for_input: result is for an input field, so only show permitted tags
  #   for_topic: results are for tagging a topic
  #   selected_tags: an array of tag names that are in the current selection (legacy)
  #   selected_tag_ids: an array of tag ids that are in the current selection
  #   only_tag_names: limit results to tags with these names
  #   exclude_synonyms: exclude synonyms from results
  #   order_search_results: result should be ordered for name search results
  #   order_popularity: order result by topic_count
  #   excluded_tag_names: an array of tag names not to include in the results
  def self.filter_allowed_tags(guardian, opts = {})
    selected_tag_ids =
      if opts[:selected_tag_ids].present?
        opts[:selected_tag_ids].map(&:to_i)
      elsif opts[:selected_tags].present?
        Tag.where_name(opts[:selected_tags]).pluck(:id)
      else
        []
      end
    category = opts[:category]
    category_has_tag_groups = category && category.tag_groups.count > 0
    category_has_restricted_tags = category_has_tag_groups || (category && category.tags.count > 0)

    # If guardian is nil, it means the caller doesn't want tags to be filtered
    # based on guardian rules. Use the same rules as for admin users.
    filter_for_non_admin = !guardian.nil? && !guardian.is_admin?

    builder_params = {}

    builder_params[:selected_tag_ids] = selected_tag_ids unless selected_tag_ids.empty?

    sql = +"WITH #{TAG_GROUP_RESTRICTIONS_SQL}, #{CATEGORY_RESTRICTIONS_SQL}"
    if (opts[:for_input] || opts[:for_topic]) && filter_for_non_admin
      sql << ", #{PERMITTED_TAGS_SQL} "
      builder_params[:group_ids] = permitted_group_ids(guardian)
      sql.gsub!("/*and_group_ids*/", "AND group_id IN (:group_ids)")
    end

    outer_join = category.nil? || category.allow_global_tags || !category_has_restricted_tags

    topic_count_column = Tag.topic_count_column(guardian)

    distinct_clause =
      if opts[:order_popularity]
        "DISTINCT ON (#{topic_count_column}, name)"
      elsif opts[:order_search_results] && opts[:term].present?
        "DISTINCT ON (lower(name) = lower(:cleaned_term), #{topic_count_column}, name)"
      else
        ""
      end

    sql << <<~SQL
      SELECT #{distinct_clause} t.id, t.name, t.#{topic_count_column}, t.pm_topic_count, t.description,
        tgr.tgm_id as tgm_id, tgr.tag_group_id as tag_group_id, tgr.parent_tag_id as parent_tag_id,
        tgr.one_per_topic as one_per_topic, t.target_tag_id
      FROM tags t
      INNER JOIN tag_group_restrictions tgr ON tgr.tag_id = t.id
      #{outer_join ? "LEFT OUTER" : "INNER"}
        JOIN category_restrictions cr ON t.id = cr.tag_id AND (tgr.tag_group_id = cr.category_tag_group_id OR cr.category_tag_group_id IS NULL)
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
        (
          if builder_params[:selected_tag_ids]
            "tgm_id IS NULL OR parent_tag_id IS NULL OR parent_tag_id IN (:selected_tag_ids)"
          else
            "tgm_id IS NULL OR parent_tag_id IS NULL"
          end
        ),
      )
    end

    if category && category_has_restricted_tags
      builder.where(
        category.allow_global_tags ? "category_id = ? OR category_id IS NULL" : "category_id = ?",
        category.id,
      )
    elsif category || opts[:for_input] || opts[:for_topic]
      # tags not restricted to any categories
      builder.where("category_id IS NULL")
    end

    if filter_for_non_admin && (opts[:for_input] || opts[:for_topic])
      # exclude staff-only tag groups
      builder.where(
        "tag_group_id IS NULL OR tag_group_id IN (SELECT tag_group_id FROM permitted_tag_groups)",
      )
    end

    term = opts[:term]
    if term.present?
      builder_params[:cleaned_term] = term

      if opts[:term_type] == DiscourseTagging.term_types[:starts_with]
        builder.where("starts_with(LOWER(name), LOWER(:cleaned_term))")
        sql.gsub!("/*and_name_like*/", "AND starts_with(LOWER(t.name), LOWER(:cleaned_term))")
      else
        builder.where("position(LOWER(:cleaned_term) IN LOWER(t.name)) <> 0")
        sql.gsub!("/*and_name_like*/", "AND position(LOWER(:cleaned_term) IN LOWER(t.name)) <> 0")
      end
    else
      sql.gsub!("/*and_name_like*/", "")
    end

    # show required tags for non-staff
    # or for staff when
    # - there are more available tags than the query limit
    # - and no search term has been included
    required_tag_ids = nil
    required_category_tag_group = nil
    if opts[:for_input] && category&.category_required_tag_groups.present? &&
         (filter_for_non_admin || term.blank?)
      category.category_required_tag_groups.each do |crtg|
        group_tags = crtg.tag_group.tags.pluck(:id)
        next if (group_tags & selected_tag_ids).size >= crtg.min_count
        if filter_for_non_admin || group_tags.size >= opts[:limit].to_i
          required_category_tag_group = crtg
          required_tag_ids = group_tags
          builder.where("id IN (?)", required_tag_ids)
        end
        break
      end
    end

    if filter_for_non_admin
      group_ids = permitted_group_ids(guardian)

      builder.where(<<~SQL, group_ids, group_ids)
        id NOT IN (
          (SELECT tgm.tag_id
           FROM tag_group_permissions tgp
           INNER JOIN tag_groups tg ON tgp.tag_group_id = tg.id
           INNER JOIN tag_group_memberships tgm ON tg.id = tgm.tag_group_id
           WHERE tgp.group_id NOT IN (?))

          EXCEPT

          (SELECT tgm.tag_id
           FROM tag_group_permissions tgp
           INNER JOIN tag_groups tg ON tgp.tag_group_id = tg.id
           INNER JOIN tag_group_memberships tgm ON tg.id = tgm.tag_group_id
           WHERE tgp.group_id IN (?))
        )
      SQL
    end

    if builder_params[:selected_tag_ids] && (opts[:for_input] || opts[:for_topic])
      one_tag_per_group_sql = +<<~SQL
        SELECT DISTINCT(tg.id)
          FROM tag_groups tg
        INNER JOIN tag_group_memberships tgm ON tg.id = tgm.tag_group_id AND tgm.tag_id IN (?)
         WHERE tg.one_per_topic
      SQL

      query_params = [builder_params[:selected_tag_ids]]

      if category_has_tag_groups
        one_tag_per_group_sql << "AND tg.id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id = ?)"
        query_params << category.id
      end

      one_tag_per_group_ids = DB.query(one_tag_per_group_sql, *query_params).map(&:id)

      if one_tag_per_group_ids.present?
        builder.where(
          "t.id NOT IN (SELECT DISTINCT tag_id FROM tag_group_restrictions WHERE tag_group_id IN (?)) OR id IN (:selected_tag_ids)",
          one_tag_per_group_ids,
        )
      end
    end

    builder.where("target_tag_id IS NULL") if opts[:exclude_synonyms]

    if opts[:exclude_has_synonyms]
      builder.where("id NOT IN (SELECT target_tag_id FROM tags WHERE target_tag_id IS NOT NULL)")
    end

    builder.where("name NOT IN (?)", opts[:excluded_tag_names]) if opts[:excluded_tag_names]&.any?

    if opts[:limit]
      if required_tag_ids && term.blank?
        # override limit so all required tags are shown by default
        builder.limit(required_tag_ids.size)
      else
        builder.limit(opts[:limit])
      end
    end

    if opts[:order_popularity]
      builder.order_by("#{topic_count_column} DESC, name")
    elsif opts[:order_search_results] && term.present?
      builder.order_by("lower(name) = lower(:cleaned_term) DESC, #{topic_count_column} DESC, name")
    end

    result = builder.query(builder_params).uniq { |t| t.id }

    if opts[:with_context]
      context = {}
      if required_category_tag_group
        context[:required_tag_group] = {
          name: required_category_tag_group.tag_group.name,
          min_count: required_category_tag_group.min_count,
        }
      end
      [result, context]
    else
      result
    end
  end

  def self.visible_tags(guardian)
    if guardian&.is_admin?
      Tag.all
    else
      # Visible tags either have no permissions or have allowable permissions
      Tag
        .where.not(id: TagGroupMembership.joins(tag_group: :tag_group_permissions).select(:tag_id))
        .or(
          Tag.where(
            id:
              TagGroupPermission
                .joins(tag_group: :tag_group_memberships)
                .where(group_id: permitted_group_ids_query(guardian))
                .select("tag_group_memberships.tag_id"),
          ),
        )
    end
  end

  def self.filter_visible(query, guardian = nil)
    guardian&.is_admin? ? query : query.where(id: visible_tags(guardian).select(:id))
  end

  def self.hidden_tag_names(guardian = nil)
    if guardian&.is_admin?
      []
    else
      # Hidden tags have at least one TagGroupPermission but must not have any for permitted groups
      Tag
        .where(id: TagGroupMembership.joins(tag_group: :tag_group_permissions).select(:tag_id))
        .where.not(
          id:
            TagGroupPermission
              .joins(tag_group: :tag_group_memberships)
              .where(group_id: permitted_group_ids_query(guardian))
              .select("tag_group_memberships.tag_id"),
        )
        .pluck(:name)
    end
  end

  def self.permitted_group_ids_query(guardian = nil)
    if guardian&.authenticated?
      Group.from(
        Group.sanitize_sql(
          [
            "(SELECT ? AS id UNION #{guardian.user.groups.select(:id).to_sql}) as groups",
            Group::AUTO_GROUPS[:everyone],
          ],
        ),
      ).select(:id)
    else
      Group.from(
        Group.sanitize_sql(["(SELECT ? AS id) AS groups", Group::AUTO_GROUPS[:everyone]]),
      ).select(:id)
    end
  end

  def self.permitted_group_ids(guardian = nil)
    permitted_group_ids_query(guardian).pluck(:id)
  end

  # read-only tags for this user
  def self.readonly_tag_names(guardian = nil)
    return [] if guardian&.is_admin?

    query =
      Tag.joins(tag_groups: :tag_group_permissions).where(
        "tag_group_permissions.permission_type = ?",
        TagGroupPermission.permission_types[:readonly],
      )

    query.pluck(:name)
  end

  # explicit permissions to use these tags
  def self.permitted_tag_names(guardian = nil)
    query =
      Tag.joins(tag_groups: :tag_group_permissions).where(
        tag_group_permissions: {
          group_id: permitted_group_ids(guardian),
          permission_type: TagGroupPermission.permission_types[:full],
        },
      )

    query.pluck(:name).uniq
  end

  # middle level of tag group restrictions
  def self.staff_tag_names
    tag_names = Discourse.cache.read(TAGS_STAFF_CACHE_KEY)

    if !tag_names
      tag_names =
        Tag
          .joins(tag_groups: :tag_group_permissions)
          .where(
            tag_group_permissions: {
              group_id: Group::AUTO_GROUPS[:everyone],
              permission_type: TagGroupPermission.permission_types[:readonly],
            },
          )
          .pluck(:name)
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
    tag.gsub!(/[[:space:]]+/, "-")
    tag.gsub!(/[^[:word:][:punct:]]+/, "")
    tag.gsub!(TAGS_FILTER_REGEXP, "")
    tag.squeeze!("-")
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

    saving_tags = opts[:unlimited] ? tag_names : tag_names[0...SiteSetting.max_tags_per_topic]
    DiscoursePluginRegistry.apply_modifier(:tags_for_saving, saving_tags, tag_names, guardian, opts)
  end

  def self.add_or_create_tags_by_name(taggable, tag_names_arg, opts = {})
    tag_names =
      DiscourseTagging.tags_for_saving(tag_names_arg, Guardian.new(Discourse.system_user), opts) ||
        []
    if taggable.tags.pluck(:name).sort != tag_names.sort
      taggable.tags = Tag.where_name(tag_names).all
      new_tag_names =
        taggable.tags.size < tag_names.size ? tag_names - taggable.tags.map(&:name) : []
      taggable.tags << Tag
        .where(target_tag_id: taggable.tags.map(&:id))
        .where.not(id: taggable.tags.map(&:id))
        .all
      new_tag_names.each { |name| taggable.tags << Tag.create(name: name) }
    end
  end

  # Add synonyms to a target tag.
  #
  # - ensures synonym tags do not already have synonyms,
  # - adds the synonyms to tag groups, categories of the target tag
  # - moves topic_tags of the synonym to the target tag
  #
  # @!attribute target_tag [Tag] the tag to which synonyms will be added
  # @!attribute synonym_tag_ids [Array<Integer>] existing tag IDs to be added as synonyms
  # @!attribute new_synonym_names [Array<String>] new tag names to be created as synonyms
  # @return [true, Hash] true if all synonyms were added successfully or a hash of
  #   failed synonym names with error messages
  def self.add_or_create_synonyms(target_tag, synonym_tag_ids: [], new_synonym_names: [])
    return true if synonym_tag_ids.blank? && new_synonym_names.blank?

    # normalize inputs
    synonym_tag_ids -= [target_tag.id]
    cleaned_names =
      (tags_for_saving(new_synonym_names, Guardian.new(Discourse.system_user)) || []) -
        [target_tag.name]

    # single query: find candidates + check if they have synonyms
    candidates =
      DB.query(
        <<~SQL,
      SELECT t.id, t.name,
             EXISTS(SELECT 1 FROM tags s WHERE s.target_tag_id = t.id) AS has_synonyms
      FROM tags t
      WHERE (LOWER(t.name) IN (:names) OR t.id IN (:ids))
        AND t.id != :target_id
    SQL
        ids: synonym_tag_ids,
        names: cleaned_names.map(&:downcase),
        target_id: target_tag.id,
      )

    valid_ids = []
    failed = {}
    existing_names = Set.new

    candidates.each do |c|
      existing_names << c.name.downcase
      if c.has_synonyms
        failed[c.name] = I18n.t("tags.synonyms_exist")
      else
        valid_ids << c.id
      end
    end
    # set target_tag_id on existing tags
    Tag.where(id: valid_ids).update_all(target_tag_id: target_tag.id)

    # create new tags for names that don't exist
    names_to_create = cleaned_names.reject { |n| existing_names.include?(n.downcase) }
    if names_to_create.present?
      now = Time.current
      rows =
        names_to_create.map do |n|
          { name: n, target_tag_id: target_tag.id, created_at: now, updated_at: now }
        end
      valid_ids += Tag.insert_all(rows, returning: :id).pluck("id")
    end

    return failed.presence || true if valid_ids.blank?

    # copy associations and consolidate topic_tags
    DB.exec(<<~SQL, synonym_ids: valid_ids, target_id: target_tag.id)
      INSERT INTO tag_group_memberships (tag_id, tag_group_id, created_at, updated_at)
      SELECT s.id, tgm.tag_group_id, NOW(), NOW()
      FROM unnest(ARRAY[:synonym_ids]::int[]) s(id)
      JOIN tag_group_memberships tgm ON tgm.tag_id = :target_id
      ON CONFLICT DO NOTHING;

      INSERT INTO category_tags (tag_id, category_id, created_at, updated_at)
      SELECT s.id, ct.category_id, NOW(), NOW()
      FROM unnest(ARRAY[:synonym_ids]::int[]) s(id)
      JOIN category_tags ct ON ct.tag_id = :target_id
      ON CONFLICT DO NOTHING;

      WITH keep AS (
        SELECT MIN(id) AS id FROM topic_tags
        WHERE tag_id IN (:synonym_ids)
          AND topic_id NOT IN (SELECT topic_id FROM topic_tags WHERE tag_id = :target_id)
        GROUP BY topic_id
      )
      DELETE FROM topic_tags WHERE tag_id IN (:synonym_ids) AND id NOT IN (SELECT id FROM keep);

      UPDATE topic_tags SET tag_id = :target_id WHERE tag_id IN (:synonym_ids);
    SQL

    Scheduler::Defer.later("Update tag topic counts") { Tag.ensure_consistency! }
    failed.presence || true
  end

  def self.muted_tags(user)
    return [] unless user
    TagUser.lookup(user, :muted).joins(:tag).pluck("tags.name")
  end
end
