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

  def fetch_category(params:)
    Category.find_by(id: params.categoryId) if params.categoryId.present?
  end

  def has_term_for_input(params:)
    params.term.present? && params.filterForInput
  end

  def has_term(params:)
    params.term.present?
  end

  def search_tags(params:, category:, guardian:)
    filter_options = params.filter_options.merge(category: category)

    tags_with_counts, filter_result_context =
      DiscourseTagging.filter_allowed_tags(guardian, **filter_options, with_context: true)

    tags_with_counts = Tag.with_localizations(tags_with_counts)

    context[:tags] = TagsController.tag_counts_json(tags_with_counts, guardian)
    context[:required_tag_group] = filter_result_context[:required_tag_group]
    context[:forbidden] = nil
    context[:forbidden_message] = nil
  end

  def append_disabled_tags(params:, category:, tags:, guardian:)
    selected_ids = params.resolved_selected_tag_ids
    skip_ids = tags.map { |t| t[:id] } | selected_ids

    candidate_tags =
      DiscourseTagging
        .filter_visible(
          Tag.where("position(LOWER(?) IN LOWER(tags.name)) <> 0", params.term),
          guardian,
        )
        .where.not(id: skip_ids)
        .limit(SiteSetting.max_tag_search_results)
        .to_a

    return if candidate_tags.empty?

    excluded_tags = reject_allowed_tags(candidate_tags, params:, category:, tags:, guardian:)

    disabled =
      excluded_tags.map do |tag|
        reason = explain_exclusion(tag, params, selected_ids, guardian)
        { id: tag.id, name: tag.name, text: tag.name, count: 0, disabled: true, title: reason }
      end

    context[:tags] = tags.concat(disabled) if disabled.present?
  end

  def detect_forbidden_tag(params:, category:, tags:, guardian:)
    return if tags.any? { |h| h[:name].downcase == params.term.downcase }

    tag = Tag.where_name(params.term).first
    return unless tag && guardian.can_see_tag?(tag)
    return if reject_allowed_tags([tag], params:, category:, tags:, guardian:).empty?

    context[:forbidden] = params.q
    context[:forbidden_message] = explain_exclusion(
      tag,
      params,
      params.resolved_selected_tag_ids,
      guardian,
    )
  end

  def reject_allowed_tags(candidates, params:, category:, tags:, guardian:)
    return candidates unless params.capped_limit && tags.size >= params.capped_limit

    only_tag_names = candidates.map(&:name)

    allowed_names =
      DiscourseTagging
        .filter_allowed_tags(
          guardian,
          **params.filter_options.merge(category:, only_tag_names:, limit: nil),
        )
        .map(&:name)
        .to_set

    candidates.reject { |tag| allowed_names.include?(tag.name) }
  end

  def explain_exclusion(tag, params, selected_ids, guardian)
    if params.excludeSynonyms && tag.synonym?
      return I18n.t("tags.forbidden.synonym", tag_name: tag.target_tag.name)
    end

    if params.excludeHasSynonyms && tag.synonyms.exists?
      return I18n.t("tags.forbidden.has_synonyms", tag_name: tag.name)
    end

    if selected_ids.present?
      group =
        TagGroup
          .joins(:tag_group_memberships)
          .where(one_per_topic: true, tag_group_memberships: { tag_id: tag.id })
          .where(id: TagGroupMembership.where(tag_id: selected_ids).select(:tag_group_id))
          .first
      return I18n.t("tags.forbidden.one_tag_per_topic_group", tag_group_name: group.name) if group
    end

    if params.filterForInput
      group =
        TagGroup
          .joins(:tag_group_memberships)
          .where(tag_group_memberships: { tag_id: tag.id })
          .where.not(parent_tag_id: [nil, *selected_ids])
          .includes(:parent_tag)
          .first
      if group&.parent_tag && guardian.can_see_tag?(group.parent_tag)
        return(
          I18n.t(
            "tags.forbidden.missing_parent_tag",
            parent_tag_name: group.parent_tag.name,
            tag_group_name: group.name,
          )
        )
      end
    end

    category_names = tag.categories.where(id: guardian.allowed_category_ids).pluck(:name)
    category_names +=
      Category
        .joins(tag_groups: :tags)
        .where(id: guardian.allowed_category_ids, "tags.id": tag.id)
        .pluck(:name)

    if category_names.present?
      category_names.uniq!
      I18n.t(
        "tags.forbidden.restricted_to",
        count: category_names.count,
        tag_name: tag.name,
        category_names: category_names.join(", "),
      )
    else
      I18n.t("tags.forbidden.in_this_category", tag_name: tag.name)
    end
  end
end
