require_dependency 'discourse_tagging'

class SiteSerializer < ApplicationSerializer

  attributes :default_archetype,
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
             :suppressed_from_homepage_category_ids,
             :post_action_types,
             :topic_flag_types,
             :can_create_tag,
             :can_tag_topics,
             :tags_filter_regexp,
             :top_tags

  has_many :categories, serializer: BasicCategorySerializer, embed: :objects
  has_many :trust_levels, embed: :objects
  has_many :archetypes, embed: :objects, serializer: ArchetypeSerializer
  has_many :user_fields, embed: :objects, serialzer: UserFieldSerializer

  def groups
    cache_fragment("group_names") do
      Group.order(:name).pluck(:id,:name).map { |id,name| { id: id, name: name } }.as_json
    end
  end

  def post_action_types
    cache_fragment("post_action_types_#{I18n.locale}") do
      ActiveModel::ArraySerializer.new(PostActionType.ordered).as_json
    end
  end

  def topic_flag_types
    cache_fragment("post_action_flag_types_#{I18n.locale}") do
      flags = PostActionType.ordered.where(name_key: ['inappropriate', 'spam', 'notify_moderators'])
      ActiveModel::ArraySerializer.new(flags, each_serializer: TopicFlagTypeSerializer).as_json
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
    SiteSetting.tagging_enabled && scope.can_create_tag?
  end

  def can_tag_topics
    SiteSetting.tagging_enabled && scope.can_tag_topics?
  end

  def include_tags_filter_regexp?
    SiteSetting.tagging_enabled
  end
  def tags_filter_regexp
    DiscourseTagging::TAGS_FILTER_REGEXP.source
  end

  def include_top_tags?
    SiteSetting.tagging_enabled && SiteSetting.show_filter_by_tag
  end
  def top_tags
    Tag.top_tags
  end

end
