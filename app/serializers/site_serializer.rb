# frozen_string_literal: true

class SiteSerializer < ApplicationSerializer

  attributes(
    :default_archetype,
    :notification_types,
    :post_types,
    :groups,
    :filters,
    :periods,
    :top_menu_items,
    :anonymous_top_menu_items,
    :uncategorized_category_id, # this is hidden so putting it here
    :is_readonly,
    :disabled_plugins,
    :user_field_max_length,
    :post_action_types,
    :topic_flag_types,
    :can_create_tag,
    :can_tag_topics,
    :can_tag_pms,
    :tags_filter_regexp,
    :top_tags,
    :wizard_required,
    :topic_featured_link_allowed_category_ids,
    :user_themes,
    :censored_regexp,
    :shared_drafts_category_id
  )

  has_many :categories, serializer: SiteCategorySerializer, embed: :objects
  has_many :trust_levels, embed: :objects
  has_many :archetypes, embed: :objects, serializer: ArchetypeSerializer
  has_many :user_fields, embed: :objects, serializer: UserFieldSerializer
  has_many :auth_providers, embed: :objects, serializer: AuthProviderSerializer

  def user_themes
    cache_fragment("user_themes") do
      Theme.where('id = :default OR user_selectable',
                    default: SiteSetting.default_theme_id)
        .order(:name)
        .pluck(:id, :name)
        .map { |id, n| { theme_id: id, name: n, default: id == SiteSetting.default_theme_id } }
        .as_json
    end
  end

  def groups
    cache_anon_fragment("group_names") do
      object.groups.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }.as_json
    end
  end

  def post_action_types
    cache_fragment("post_action_types_#{I18n.locale}") do
      types = ordered_flags(PostActionType.types.values)
      ActiveModel::ArraySerializer.new(types).as_json
    end
  end

  def topic_flag_types
    cache_fragment("post_action_flag_types_#{I18n.locale}") do
      types = ordered_flags(PostActionType.topic_flag_types.values)
      ActiveModel::ArraySerializer.new(types, each_serializer: TopicFlagTypeSerializer).as_json
    end
  end

  def default_archetype
    Archetype.default
  end

  def post_types
    Post.types
  end

  def filters
    Discourse.filters.map(&:to_s)
  end

  def periods
    TopTopic.periods.map(&:to_s)
  end

  def top_menu_items
    Discourse.top_menu_items.map(&:to_s)
  end

  def anonymous_top_menu_items
    Discourse.anonymous_top_menu_items.map(&:to_s)
  end

  def uncategorized_category_id
    SiteSetting.uncategorized_category_id
  end

  def is_readonly
    Discourse.readonly_mode?
  end

  def disabled_plugins
    Discourse.disabled_plugin_names
  end

  def user_field_max_length
    UserField.max_length
  end

  def can_create_tag
    scope.can_create_tag?
  end

  def can_tag_topics
    scope.can_tag_topics?
  end

  def can_tag_pms
    scope.can_tag_pms?
  end

  def include_tags_filter_regexp?
    SiteSetting.tagging_enabled
  end

  def tags_filter_regexp
    DiscourseTagging::TAGS_FILTER_REGEXP.source
  end

  def include_top_tags?
    Tag.include_tags?
  end

  def top_tags
    Tag.top_tags(guardian: scope)
  end

  def wizard_required
    true
  end

  def include_wizard_required?
    Wizard.user_requires_completion?(scope.user)
  end

  def include_topic_featured_link_allowed_category_ids?
    SiteSetting.topic_featured_link_enabled
  end

  def topic_featured_link_allowed_category_ids
    scope.topic_featured_link_allowed_category_ids
  end

  def censored_regexp
    WordWatcher.word_matcher_regexp(:censor)&.source
  end

  def shared_drafts_category_id
    SiteSetting.shared_drafts_category.to_i
  end

  def include_shared_drafts_category_id?
    scope.can_create_shared_draft?
  end

  private

  def ordered_flags(flags)
    notify_moderators_type = PostActionType.flag_types[:notify_moderators]
    types = flags

    if notify_moderators_flag = types.index(notify_moderators_type)
      types.insert(types.length, types.delete_at(notify_moderators_flag))
    end

    types.map { |id| PostActionType.new(id: id) }
  end
end
