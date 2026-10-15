# frozen_string_literal: true

class Tags::Search
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [String] :q Search query
  #   @option params [Integer] :limit Max results
  #   @option params [Integer] :categoryId Category to scope search to
  #   @option params [Array<Integer>] :selected_tag_ids Currently selected tag IDs
  #   @option params [Array<String>] :selected_tags Currently selected tag names (deprecated)
  #   @option params [Boolean] :filterForInput Whether filtering for tag input
  #   @option params [Boolean] :excludeSynonyms Exclude synonym tags
  #   @option params [Boolean] :excludeHasSynonyms Exclude tags that have synonyms
  #   @return [Service::Base::Context]

  params do
    attribute :q, :string
    attribute :limit, :integer
    attribute :categoryId, :integer
    attribute :selected_tag_ids, :array
    attribute :selected_tags, :array
    attribute :filterForInput, :boolean
    attribute :excludeSynonyms, :boolean
    attribute :excludeHasSynonyms, :boolean
    attribute :prioritizeRecentTags, :boolean

    validate :limit_is_valid

    def limit_is_valid
      raw = raw_attributes["limit"]
      return if raw.blank?

      unless raw.to_s.match?(/\A\d+\z/)
        errors.add(:limit, :invalid)
        return
      end

      value = raw.to_i
      errors.add(:limit, :invalid) if value < 0 || value > SiteSetting.max_tag_search_results
    end

    def term
      q.present? ? DiscourseTagging.clean_tag(q) : nil
    end

    def capped_limit
      limit.present? ? [limit, SiteSetting.max_tag_search_results].min : nil
    end

    def filter_options
      opts = {
        for_input: filterForInput,
        selected_tags: selected_tags,
        selected_tag_ids: selected_tag_ids,
        exclude_synonyms: excludeSynonyms,
        exclude_has_synonyms: excludeHasSynonyms,
      }

      opts[:limit] = capped_limit if capped_limit

      if term.present?
        opts[:term] = term
        opts[:order_search_results] = true
      else
        opts[:order_popularity] = true
      end

      opts
    end

    def resolved_selected_tag_ids
      if selected_tag_ids.present?
        selected_tag_ids.map(&:to_i)
      elsif selected_tags.present?
        Tag.where_name(selected_tags).pluck(:id)
      else
        []
      end
    end
  end

  model :category, optional: true
  step :search_tags
  only_if(:has_term_for_input) { step :append_disabled_tags }
  only_if(:has_term) { step :detect_forbidden_tag }

  private

  def fetch_category(params:, guardian:)
    return if params.categoryId.blank?
    Category.where(id: params.categoryId).where(id: guardian.allowed_category_ids).first
  end

  def has_term_for_input(params:)
    params.term.present? && params.filterForInput
  end

  def has_term(params:)
    params.term.present?
  end

  def visible_tags(guardian)
    DiscourseTagging.visible_tags(guardian)
  end

  def tag_visible?(tag_id, guardian)
    DiscourseTagging.visible_tags(guardian).exists?(id: tag_id)
  end

  def search_tags(params:, category:, guardian:)
    filter_options = params.filter_options.merge(category: category)

    if (recent_tag_ids = recent_priority_tag_ids(params:, guardian:))
      filter_options[:order_recent_tag_ids] = recent_tag_ids
    end

    tags_with_counts, filter_result_context =
      DiscourseTagging.filter_allowed_tags(guardian, **filter_options, with_context: true)

    tags_with_counts = Tag.with_localizations(tags_with_counts)

    context[:tags] = TagsController.tag_counts_json(tags_with_counts, guardian)
    context[:required_tag_group] = filter_result_context[:required_tag_group]
    context[:remaining_required_tag_count] = filter_result_context[:remaining_required_tag_count]
    context[:forbidden] = nil
    context[:forbidden_message] = nil
  end

  def recent_priority_tag_ids(params:, guardian:)
    return unless params.prioritizeRecentTags && params.term.blank?
    return if guardian.anonymous?
    return unless UpcomingChanges.enabled_for_user?(:prioritize_recently_used_tags, guardian.user)

    Tag.recently_used_by(guardian.user).presence
  end

  def append_disabled_tags(
    params:,
    category:,
    tags:,
    guardian:,
    required_tag_group:,
    remaining_required_tag_count:
  )
    selected_tag_ids = params.resolved_selected_tag_ids
    skip_ids = tags.map { |tag| tag[:id] } | selected_tag_ids

    candidate_tags =
      visible_tags(guardian)
        .where("tags.name ~* ?", "\\m#{Regexp.escape(params.term)}")
        .where.not(id: skip_ids)
        .limit(SiteSetting.max_tag_search_results)
        .to_a

    return if candidate_tags.empty?

    excluded_tags = tags_excluded_by_filter(candidate_tags, params:, category:, tags:, guardian:)
    return if excluded_tags.empty?

    allowed_without_required_tag_groups =
      if remaining_required_tag_count&.positive?
        DiscourseTagging
          .filter_allowed_tags(
            guardian,
            **params.filter_options.merge(
              category:,
              only_tag_names: excluded_tags.map(&:name),
              limit: nil,
              ignore_required_tag_groups: true,
            ),
          )
          .map(&:name)
          .to_set
      else
        Set.new
      end

    disabled_tags =
      excluded_tags.map do |tag|
        title =
          if allowed_without_required_tag_groups.include?(tag.name)
            I18n.t(
              "tags.forbidden.required_tag_group",
              count: remaining_required_tag_count,
              tag_group_name: required_tag_group[:name],
            )
          else
            explain_exclusion(tag, params:, selected_tag_ids:, guardian:)
          end
        { id: tag.id, name: tag.name, text: tag.name, count: 0, disabled: true, title: }
      end

    tags.concat(disabled_tags)
  end

  def detect_forbidden_tag(params:, category:, tags:, guardian:)
    return if tags.any? { |h| h[:name].downcase == params.term.downcase }

    tag = visible_tags(guardian).where_name(params.term).first
    return unless tag
    return if tags_excluded_by_filter([tag], params:, category:, tags:, guardian:).empty?

    context[:forbidden] = params.q
    context[:forbidden_message] = explain_exclusion(
      tag,
      params:,
      selected_tag_ids: params.resolved_selected_tag_ids,
      guardian:,
    )
  end

  def tags_excluded_by_filter(candidates, params:, category:, tags:, guardian:)
    limit = params.capped_limit
    return candidates unless limit && tags.size >= limit

    allowed_tag_names =
      DiscourseTagging
        .filter_allowed_tags(
          guardian,
          **params.filter_options.merge(
            category:,
            only_tag_names: candidates.map(&:name),
            limit: nil,
          ),
        )
        .map(&:name)
        .to_set

    candidates.reject { |tag| allowed_tag_names.include?(tag.name) }
  end

  def explain_exclusion(tag, params:, selected_tag_ids:, guardian:)
    synonym_exclusion_reason(tag, params:, guardian:) ||
      has_synonyms_exclusion_reason(tag, params:) ||
      one_per_topic_group_exclusion_reason(tag, selected_tag_ids:, guardian:) ||
      missing_parent_tag_exclusion_reason(tag, params:, selected_tag_ids:, guardian:) ||
      category_restriction_exclusion_reason(tag, params:, guardian:)
  end

  def synonym_exclusion_reason(tag, params:, guardian:)
    unless params.excludeSynonyms && tag.synonym? && tag_visible?(tag.target_tag_id, guardian)
      return
    end

    I18n.t("tags.forbidden.synonym", tag_name: tag.target_tag.name)
  end

  def has_synonyms_exclusion_reason(tag, params:)
    return unless params.excludeHasSynonyms && tag.synonyms.exists?

    I18n.t("tags.forbidden.has_synonyms", tag_name: tag.name)
  end

  def one_per_topic_group_exclusion_reason(tag, selected_tag_ids:, guardian:)
    return if selected_tag_ids.blank?

    group =
      TagGroup
        .joins(:tag_group_memberships)
        .where(one_per_topic: true, tag_group_memberships: { tag_id: tag.id })
        .where(id: TagGroupMembership.where(tag_id: selected_tag_ids).select(:tag_group_id))
        .first
    return unless group

    conflicting_tag_names =
      visible_tags(guardian)
        .where(id: selected_tag_ids)
        .joins(:tag_group_memberships)
        .where(tag_group_memberships: { tag_group_id: group.id })
        .order(:name)
        .pluck(:name)

    if conflicting_tag_names.blank?
      return I18n.t("tags.forbidden.one_tag_per_topic_group_without_names")
    end

    I18n.t(
      "tags.forbidden.one_tag_per_topic_group",
      tag_group_name: group.name,
      tag_names: conflicting_tag_names.join(", "),
    )
  end

  def missing_parent_tag_exclusion_reason(tag, params:, selected_tag_ids:, guardian:)
    return unless params.filterForInput

    group =
      TagGroup
        .joins(:tag_group_memberships)
        .where(tag_group_memberships: { tag_id: tag.id })
        .where.not(parent_tag_id: [nil, *selected_tag_ids])
        .includes(:parent_tag)
        .first
    return unless group&.parent_tag && tag_visible?(group.parent_tag_id, guardian)

    I18n.t(
      "tags.forbidden.missing_parent_tag",
      parent_tag_name: group.parent_tag.name,
      tag_group_name: group.name,
    )
  end

  def category_restriction_exclusion_reason(tag, params:, guardian:)
    allowed_category_ids = guardian.allowed_category_ids
    category_names =
      tag.categories.where(id: allowed_category_ids).pluck(:name) +
        Category
          .joins(tag_groups: :tags)
          .where(id: allowed_category_ids, "tags.id": tag.id)
          .pluck(:name)
    category_names = category_names.uniq.sort

    if category_names.empty?
      if params.categoryId.present?
        return I18n.t("tags.forbidden.in_this_category", tag_name: tag.name)
      end

      return I18n.t("tags.forbidden.not_allowed", tag_name: tag.name)
    end

    if category_names.size > 3
      return(
        I18n.t(
          "tags.forbidden.restricted_to_truncated",
          tag_name: tag.name,
          category_names: category_names.first(3).join(", "),
          more_count: category_names.size - 3,
        )
      )
    end

    I18n.t(
      "tags.forbidden.restricted_to",
      count: category_names.size,
      tag_name: tag.name,
      category_names: category_names.join(", "),
    )
  end
end
